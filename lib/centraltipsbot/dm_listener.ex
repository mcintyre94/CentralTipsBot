defmodule Centraltipsbot.DMListener do
  use GenServer
  require Logger
  alias Centraltipsbot.{Repo, Twitter, LastProcessed}
  import Ecto.Query

  @interval Application.get_env(:centraltipsbot, :dm_listener)[:interval]
  @bot_twitter_id Application.get_env(:centraltipsbot, :dm_listener)[:bot_twitter_id]

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # Kick off the first request
    # Note: Delay this by the initial interval so that if we get into
    # a crash cycle we don't DDOS the Twitter service
    Logger.info("DM Listener started...")
    Process.send_after(self(), :check, @interval)
    {:ok, nil}
  end

  defp process_dm(dm) do
    # If it lowercase + remove spaces = "optout", then add user to optouts
    # If it contains an "@", then store that as email for the sender
    # Otherwise, log + ignore it (can't process it)
    # For all, send a read receipt
    # For processed ones, send a react emoji?
    # text = dm.message_create.message_data.text

    # TODO: actually process DMs!
    query =
      from LastProcessed,
      where: [name: "twitter_dms"],
      update: [set: [last_processed: fragment(~s<jsonb_set(last_processed, '{dm_id}', ?)>, ^dm.id)]]
    Repo.update_all(query, [])

    Logger.info("Successfully processed DM")
  end

  def handle_info(:check, _) do
    # Get last processed object from DB
    last_processed_object = LastProcessed |> Repo.get_by(name: "twitter_dms")
    %{last_processed: last_processed} = last_processed_object
    last_pagination_cursor = last_processed["pagination_cursor"]
    last_dm_id = last_processed["dm_id"]

    # Get all the DMs starting with the last pagination cursor
    %{cursor: cursor, dms: dms} = Twitter.dms_since_cursor(last_pagination_cursor)

    # We receive latest DMs first, so process until we reach last_dm_id (we may not)
    # Ignore anything that we sent
    new_dms = dms |> Enum.take_while(&(&1.id != last_dm_id)) |> Enum.filter(&(&1.message_create.sender_id != @bot_twitter_id))
    # Process from oldest to newest, ignore anything we sent
    new_dms |> Enum.reverse |> Enum.map(&process_dm(&1))

    Logger.info("Successfully processed #{Enum.count(new_dms)} new DMs")

    # Then update the pagination_cursor in the DB
    if cursor != nil do
      query =
        from LastProcessed,
        where: [name: "twitter_dms"],
        update: [set: [last_processed: fragment(~s<jsonb_set(last_processed, '{pagination_cursor}', ?)>, ^cursor)]]
      Repo.update_all(query, [])
    end

    # After the interval, perform another check
    Process.send_after(self(), :check, @interval)
    {:noreply, nil}
  end
end
