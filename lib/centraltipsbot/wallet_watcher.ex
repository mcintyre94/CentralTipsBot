defmodule Centraltipsbot.WalletWatcher do
  use GenServer
  require Logger
  alias Centraltipsbot.{Balance, LastProcessed, Repo, Twitter}
  alias Ecto.Multi

  defmodule WalletWatcherState do
    @enforce_keys [:public_key]
    defstruct [:public_key]
  end

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def check do
    send(__MODULE__, :check)
  end

  def init(:ok) do
    # Send a request after 1 hour, just to make sure we update on restarts even if we don't get more requests

    Logger.info("Wallet Watcher started...")
    one_hour = 1000 * 60 * 60 # milliseconds

    Process.send_after(self(), :check, one_hour)
    {:ok, %WalletWatcherState{
      public_key: Application.get_env(:centraltipsbot, :wallet_watcher)[:public_key]
    }}
  end

  defp update_balance(twitter_user_id, amount_received, updated_last_processed) do
    # Transactionally update the user's balance + the last processed to this transaction
    Multi.new |>
    # Either insert a new user with the amount received as their balance,
    # or upsert the balance of an existing user with same source + source_id
    Multi.insert(:update_balance,
      %Balance{
        source: "twitter",
        source_id: twitter_user_id,
        balance: amount_received
      },
      conflict_target: [:source, :source_id],
      on_conflict: [inc: [balance: amount_received]]
    ) |>
    Multi.update(:update_last_processed, updated_last_processed) |>
    Repo.transaction
  end

  defp process_transaction(transaction, last_processed_object) do
    Logger.info("Processing transaction: #{inspect(transaction)}")

    # Twitter username should be in the memo, but we don't know if it's valid yet (it could be anything)
    # Remove any leading @
    memo = transaction["memo"]
    maybe_twitter_username = memo |> String.replace_prefix("@", "")
    amount_received = transaction["amount_received"]

    # If we are able to process this transaction, we will update the last processed object to it
    updated_last_processed = LastProcessed.changeset(last_processed_object, %{last_processed: transaction})

    twitter_user_id = case Twitter.get_user(maybe_twitter_username) do
      {:ok, user} -> user.id_str
      {:err, :twitter_user_not_found} ->
        Logger.info("Unable to find twitter username in transaction memo #{memo}")
        nil
      {:err, :twitter_user_suspended} ->
        Logger.info("Twitter username in transaction memo #{memo} is suspended")
        nil
      {:err, err} -> raise err
    end

    case twitter_user_id do
      nil ->
        # Memo was not a valid Twitter user, so mark it processed and move on
        Repo.update(updated_last_processed)
      _ ->
        # Memo was a valid Twitter user, and we have their Twitter ID.
        # Update the balance for this user and mark the transaction processed
        Logger.info("Memo #{memo} is a twitter username with twitter user ID #{twitter_user_id}")
        update_balance(twitter_user_id, amount_received, updated_last_processed)
    end

    Logger.info("Successfully processed transaction")
  end

  def handle_info(:check, %WalletWatcherState{} = state) do
    # Get the last processed object from DB
    last_processed_object = LastProcessed |> Repo.get_by(name: "wallet_incoming")
    %{last_processed: last_processed} = last_processed_object

    # Request incoming transactions from the API (this returns them all)
    url = "https://www.centralized-coin.com/api/incoming/" <> state.public_key
    headers = ["User-Agent": "central.tips/latest (monitoring incoming transactions)"]
    %HTTPoison.Response{status_code: 200, body: body} = HTTPoison.get!(url, headers)

    # We receive latest transactions first, so process until we reach last_processed_object (we may not)
    transactions = Jason.decode!(body)["transactions"]
    new_transactions = transactions |> Enum.take_while(&(&1 != last_processed))

    # Process from oldest to newest
    new_transactions |> Enum.reverse |> Enum.map(&(process_transaction(&1, last_processed_object)))

    Logger.info("Successfully processed #{Enum.count(new_transactions)} new transactions")
    {:noreply, state}
  end
end
