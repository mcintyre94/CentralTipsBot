defmodule Centraltipsbot.TipProcessor do
  use GenServer
  require Logger
  alias Centraltipsbot.{Balance, Repo, Tip, Wallet}
  alias Ecto.Multi
  import Ecto.Query

  defmodule TipProcessorState do
    @enforce_keys [:interval, :enable_payments, :cc_api_key]
    defstruct [:interval, :enable_payments, :cc_api_key]
  end

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # Kick off the first request
    # Note: Delay this by the initial interval so that if we get into
    # a crash cycle we don't DDOS the DB
    interval = Application.get_env(:centraltipsbot, :tip_processor)[:interval]
    enable_payments = Application.get_env(:centraltipsbot, :tip_processor)[:enable_payments] === "true"

    Logger.info("Tip Processor started... enable_payments: #{enable_payments}")
    Process.send_after(self(), :check, interval)
    {:ok, %TipProcessorState{
      interval: interval,
      enable_payments: enable_payments,
      cc_api_key: Application.get_env(:centraltipsbot, :tip_processor)[:cc_api_key]
    }}
  end

  # Check the tip sender has sufficient balance
  def check_balance(repo, from_source, from_source_id, quantity) do
    query = from b in Balance,
              where: b.source == ^from_source,
              where: b.source_id == ^from_source_id,
              where: b.balance >= ^quantity

    case repo.one(query) do
      nil -> {:error, :from_balance_not_found_or_insufficient}
      balance -> {:ok, balance}
    end
  end

  # Reduce the balance by the given quantity
  def reduce_balance(repo, %Balance{} = balance, quantity) do
    q = Decimal.negate(quantity)
    query = from Balance,
              where: [id: ^balance.id],
              update: [inc: [balance: ^q]]

    case repo.update_all(query, []) do
      {1, nil} -> {:ok, nil}
      res -> {:error, res}
    end
  end

  # Check the tip recipient has a wallet
  def check_wallet(repo, to_source, to_source_id) do
    query = from w in Wallet,
      where: w.source == ^to_source,
      where: w.source_id == ^to_source_id,
      where: w.confirmed == true

    case repo.one(query) do
      nil -> {:error, :to_wallet_not_found_or_unconfirmed}
      wallet -> {:ok, wallet}
    end
  end

  # Mark the tip paid
  def mark_paid(repo, %Tip{} = tip) do
    query = from Tip,
              where: [id: ^tip.id],
              update: [set: [paid: true]]

    case repo.update_all(query, []) do
      {1, nil} -> {:ok, nil}
      res -> {:error, res}
    end
  end

  # Send the tip using CC API
  def send_tip(%Tip{} = tip, %Wallet{} = to_wallet, enable_payments, cc_api_key) do
    body = %{
      recipient_email: to_wallet.email,
      force: true,
      amount: tip.quantity,
      memo: tip.memo
    }

    body = case enable_payments do
      true -> Map.put(body, :token, cc_api_key)
      _ -> body
    end

    if(enable_payments) do
      url = "https://www.centralized-coin.com/api/users/send"
      body = body |> Jason.encode!
      headers = [
        "User-Agent": "central.tips/latest (sending tip)",
        "Content-Type": "application/json"
      ]
      Logger.info("Send tip for real! #{inspect(body)}")

      case HTTPoison.post(url, body, headers) do
        {:ok, %HTTPoison.Response{
          status_code: 200,
          body: "{\"success\":true}"
        }} -> {:ok, nil}
        {:ok, res} -> {:error, res}
        {:error, reason} -> {:error, reason}
      end
    else
      Logger.info("DRY RUN: Send tip #{inspect(body)}")
      {:ok, nil}
    end
  end

  def process_tip(%Tip{} = tip, enable_payments, cc_api_key) do
    case Multi.new |>
    Multi.run(:check_balance, fn repo, _ -> check_balance(repo, tip.from_source, tip.from_source_id, tip.quantity) end) |>
    Multi.run(:check_wallet, fn repo, _ -> check_wallet(repo, tip.to_source, tip.to_source_id) end) |>
    Multi.run(:reduce_balance, fn repo, %{check_balance: balance} -> reduce_balance(repo, balance, tip.quantity) end) |>
    Multi.run(:mark_paid, fn repo, _ -> mark_paid(repo, tip) end) |>
    Multi.run(:send_tip, fn _, %{check_wallet: wallet} -> send_tip(tip, wallet, enable_payments, cc_api_key) end) |>
    Repo.transaction do
      {:ok, _} -> Logger.info("Successfully paid tip #{tip.id}")
      {:error, :send_tip, res, _} ->
        # Error if the CC API errors
        Logger.error("Failure sending tip #{tip.id} using CC API. Error: #{inspect(res)}")
      {:error, stopped_at, stopped_because, _} ->
        # Anything else is a precondition failing, not an error, log + move on
        Logger.info("Unable to send tip. Stopped at #{stopped_at} because #{stopped_because}")
    end
  end

  def handle_info(:check, %TipProcessorState{} = state) do
    current_date = Date.utc_today()
    # Will get tips in the last week
    since_date = Date.add(current_date, -7)
    {:ok, since_date_naive} = NaiveDateTime.new(since_date, ~T[00:00:00.000])

    # Get unprocessed tips, oldest first
    query = from t in Tip,
              where: not(t.paid),
              where: t.inserted_at >= ^since_date_naive,
              order_by: t.inserted_at

    unprocessed_tips = query |> Repo.all

    unprocessed_tips |> Enum.map(&process_tip(&1, state.enable_payments, state.cc_api_key))

    Logger.info("Successfully processed #{Enum.count(unprocessed_tips)} unprocessed tips")

    # After the interval, perform another check
    Process.send_after(self(), :check, state.interval)
    {:noreply, state}
  end
end
