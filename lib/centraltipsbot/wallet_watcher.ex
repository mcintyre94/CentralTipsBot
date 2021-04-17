defmodule Centraltipsbot.WalletWatcher do
  use GenServer
  require Logger
  alias Centraltipsbot.{Repo, Balance, LastProcessed}
  alias Ecto.Multi

  @interval Application.get_env(:centraltipsbot, :wallet_watcher)[:interval]
  @public_key Application.get_env(:centraltipsbot, :wallet_watcher)[:public_key]

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # Kick off the first request
    # Note: Delay this by the initial interval so that if we get into
    # a crash cycle we don't DDOS the wallet service
    Process.send_after(self(), :check, @interval)
    {:ok, nil}
  end

  defp process_transaction(transaction, last_processed_object) do
    Logger.info("Processing transaction: #{inspect(transaction)}")

    memo = transaction["memo"]
    amount_received = transaction["amount_received"]

    # Transactionally update the user's balance + the last processed to this transaction
    Multi.new |>
    # Either insert a new user with the amount received as their balance,
    # or upsert the balance of an existing user with same source + source_id
    Multi.insert(:update_balance,
      %Balance{
        source: "twitter",
        source_id: memo, # TODO: Look up the memo as a Twitter username instead
        balance: amount_received
      },
      conflict_target: [:source, :source_id],
      on_conflict: [inc: [balance: amount_received]]
    ) |>
    Multi.update(:update_last_processed, LastProcessed.changeset(last_processed_object, %{last_processed: transaction})) |>
    Repo.transaction

    Logger.info("Successfully processed transaction")
  end

  def handle_info(:check, _) do
    # Get the last processed object from DB
    last_processed_object = LastProcessed |> Repo.get_by(name: "wallet_incoming")
    %{last_processed: last_processed} = last_processed_object

    # Request incoming transactions from the API (this returns them all)
    url = "https://www.centralized-coin.com/api/incoming/" <> @public_key
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url)

    # We receive latest transactions first, so process until we reach last_processed_object (we may not)
    transactions = Jason.decode!(body)["transactions"]
    new_transactions = transactions |> Enum.take_while(&(&1 != last_processed))

    # Process from oldest to newest
    new_transactions |> Enum.reverse |> Enum.map(&(process_transaction(&1, last_processed_object)))

    Logger.info("Successfully processed #{Enum.count(new_transactions)} new transactions")

    # After the interval, perform another check
    Process.send_after(self(), :check, @interval)
    {:noreply, nil}
  end
end
