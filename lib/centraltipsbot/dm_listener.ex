defmodule Centraltipsbot.DMListener do
  use GenServer
  require Logger
  alias Centraltipsbot.{Repo, Twitter, LastProcessed, Optout, Wallet}
  alias Ecto.Multi
  import Ecto.Query

  defmodule DMListenerState do
    @enforce_keys [:interval]
    defstruct [:interval]
  end

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # Kick off the first request
    # Note: Delay this by the initial interval so that if we get into
    # a crash cycle we don't DDOS the Twitter service
    Logger.info("DM Listener started...")
    interval = Application.get_env(:centraltipsbot, :dm_listener)[:interval]
    Process.send_after(self(), :check, interval)
    {:ok, %DMListenerState{
      interval: interval
    }}
  end

  defp send_confirm_dm(recipient_id, email) do
    text = "Thanks! I recorded an email of \"#{email}\". Is that correct? Please say \"Yes\" or send me your correct Email."
    quick_replies = [%{label: "Yes"}]
    Twitter.send_dm(recipient_id, text, quick_replies)
    {:ok, nil}
  end

  defp process_dm(dm, last_processed_object) do
    # If it lowercase + remove spaces = "optout", then add user to optouts
    # If it contains an "@", then store that as email for the sender
    # Otherwise, log + ignore it (can't process it)
    # For all, send a read receipt
    # For processed ones, send a react emoji?

    text = dm.message_create.message_data.text
    text_normalised = text |> String.replace(" ", "") |> String.downcase
    sender_id = dm.message_create.sender_id
    is_email? = text |> String.contains?("@")

    updated_last_processed = LastProcessed.changeset(last_processed_object, %{last_processed: %{dm_id: dm.id} })

    case text_normalised do
      "optout" ->
        # User has opted out
        Logger.info("Recording opt out for Twitter ID #{sender_id}")
        Multi.new |>
        Multi.insert(:insert_optout,
          %Optout{source: "twitter", source_id: sender_id},
          conflict_target: [:source, :source_id],
          on_conflict: :nothing
        ) |>
        Multi.update(:update_last_processed, updated_last_processed) |>
        Repo.transaction

      "optin" ->
        # User has opted in
        Logger.info("Removing opt out for Twitter ID #{sender_id}")
        Multi.new |>
        Multi.delete_all(:delete_optout, (from Optout, where: [source: "twitter", source_id: ^sender_id])) |>
        Multi.update(:update_last_processed, updated_last_processed) |>
        Repo.transaction

      _ when text_normalised in ["yes", "yep", "confirm"] ->
        # User has confirmed their email address
        Logger.info("Marking email for Twitter ID #{sender_id} as confirmed")
        Multi.new |>
        Multi.update_all(
          :mark_confirmed,
          (from Wallet,
            where: [source: "twitter", source_id: ^sender_id],
            update: [set: [confirmed: true]]),
            []
        ) |>
        Multi.update(:update_last_processed, updated_last_processed) |>
        Repo.transaction

      _ when is_email? ->
        # Assume any other message with an @ is an email address
        Logger.info("Recording #{text_normalised} as email address for Twitter ID #{sender_id}")

        Multi.new |>
        # Add the email (unconfirmed)
        Multi.insert(:set_email,
          %Wallet{
            source: "twitter",
            source_id: sender_id,
            email: text_normalised,
            confirmed: false
          },
          conflict_target: [:source, :source_id],
          on_conflict: [set: [email: text_normalised, confirmed: false]]
        ) |>
        # Prompt the user to confirm it
        Multi.run(:dm_to_confirm, fn _, _ -> send_confirm_dm(sender_id, text_normalised) end) |>
        Multi.update(:update_last_processed, updated_last_processed) |>
        Repo.transaction

      _ ->
        # Nothing to do for this DM
        Logger.info("Skipping DM ID #{dm.id} from Twitter ID #{sender_id}")
        Repo.update(updated_last_processed)
    end

    Twitter.mark_dms_read(sender_id, dm.id)
    Logger.info("Successfully processed DM")
  end

  def handle_info(:check, %DMListenerState{} = state) do
    # Get last processed object from DB
    last_processed_object = LastProcessed |> Repo.get_by(name: "twitter_dms")
    %{last_processed: last_processed} = last_processed_object
    last_dm_id = last_processed["dm_id"]

    # Get all the DMs since the last one we processed
    new_dms = Twitter.dms_received_since_id(last_dm_id)

    # Process from oldest to newest
    new_dms |> Enum.reverse |> Enum.map(&process_dm(&1, last_processed_object))

    Logger.info("Successfully processed #{Enum.count(new_dms)} new DMs")

    # After the interval, perform another check
    Process.send_after(self(), :check, state.interval)
    {:noreply, state}
  end
end
