defmodule Centraltipsbot.TweetListener do
  use GenServer
  require Logger
  alias Centraltipsbot.{LastProcessed, Repo, Tip, Twitter}
  alias Ecto.Multi

  @interval Application.get_env(:centraltipsbot, :tweet_listener)[:interval]

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # Kick off the first request
    # Note: Delay this by the initial interval so that if we get into
    # a crash cycle we don't DDOS the Twitter service
    Logger.info("Tweet Listener started...")
    Process.send_after(self(), :check, @interval)
    {:ok, nil}
  end

  @doc false
  def parse_text(text) do
    # Regex: match any number including .s and ,s immediately after the tag
    regex = ~r/@CentralTipsBot ([\d.,]*)/
    with [ tip_amount | _ ] <- Regex.run(regex, text, capture: :all_but_first),
         {parsed_tip_amount, _} <- Float.parse(tip_amount |> String.replace(",", ""))
    do
      {:ok, parsed_tip_amount}
    else
      _ -> :nil
    end
  end

  defp process_tweet(tweet, last_processed_object) do
    # First, see if we can parse a tip number out of the tweet
    # If we can, then see if we have an email for the recipient (in_reply_to_user_id)
    # If we do, then store as a TipsWithDestination
    # Else, store it as a TipsMissingDestination
    %{"text" => text, "in_reply_to_user_id" => recipient_id, "author_id" => sender_id, "id" => id} = tweet

    updated_last_processed = LastProcessed.changeset(last_processed_object, %{last_processed: %{tweet_id: id} })

    case parse_text(text) do
      nil ->
        Logger.info("No tip found in tweet #{inspect(tweet)}")
        Repo.update(updated_last_processed)

      {:ok, tip_amount} ->
        Logger.info("Parsed tip of #{tip_amount} from #{sender_id} to #{recipient_id}")

        sender_twitter_username = case Twitter.get_user(sender_id) do
          {:ok, user} -> user.screen_name
          {:err, :twitter_user_not_found} ->
            Logger.info("Unable to find twitter username for Twitter ID #{sender_id} in tweet #{id} (user not found)")
            nil
          {:err, :twitter_user_suspended} ->
            Logger.info("Unable to find twitter username for Twitter ID #{sender_id} in tweet #{id} (user suspended)")
            nil
          {:err, err} ->
            Logger.info("Unable to find twitter username for Twitter ID #{sender_id} in tweet #{id} (error: #{inspect(err)})")
            nil
        end

        # Don't need username in Twitter URL: https://stackoverflow.com/questions/27836043/get-tweet-url-having-only-tweet-id/27843083
        tweet_url = "https://twitter.com/t/status/#{id}"
        memo = case sender_twitter_username do
          nil -> "Tip for #{tweet_url} (central.tips)"
          _ -> "Tip from @#{sender_twitter_username} for #{tweet_url} (central.tips)"
        end

        tip = %Tip{
          from_source: "twitter",
          from_source_id: sender_id,
          to_source: "twitter",
          to_source_id: recipient_id,
          quantity: tip_amount,
          memo: memo,
          paid: false
        }

        Multi.new
        |> Multi.insert(:insert_tip, tip)
        |> Multi.update(:update_last_processed, updated_last_processed)
        |> Repo.transaction
    end

    Logger.info("Successfully processed Tweet")
  end

  def handle_info(:check, _) do
    # Get last processed object from DB
    last_processed_object = LastProcessed |> Repo.get_by(name: "twitter_tweets")
    %{last_processed: last_processed} = last_processed_object
    last_tweet_id = last_processed["tweet_id"]

    # Get all the Tweets since the last one
    new_tweets = Twitter.tweets_to_process_since_id(last_tweet_id)

    # Process from oldest to newest
    new_tweets |> Enum.reverse |> Enum.map(&process_tweet(&1, last_processed_object))

    Logger.info("Successfully processed #{Enum.count(new_tweets)} new tweets")

    # After the interval, perform another check
    Process.send_after(self(), :check, @interval)
    {:noreply, nil}
  end
end
