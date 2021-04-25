defmodule Centraltipsbot.Twitter do
  require Logger

  @bearer_token Application.get_env(:extwitter, :oauth)[:bearer_token]

  # Paginated API, this function makes a single call to
  # https://developer.twitter.com/en/docs/twitter-api/v1/direct-messages/sending-and-receiving/api-reference/list-events
  defp fetch_next_dms(cursor) do
    params = [count: 50] ++ case cursor do
      nil -> []
      _ -> [cursor: cursor]
    end
    params = ExTwitter.Parser.parse_request_params(params)

    try do
      ExTwitter.API.Base.request(:get, "1.1/direct_messages/events/list.json", params)
    rescue
      e in ExTwitter.RateLimitExceededError ->
        sleep_for_seconds = e.reset_in + 1
        Logger.info("Got Twitter rate limit, waiting #{sleep_for_seconds} seconds before re-trying")
        :timer.sleep (sleep_for_seconds * 1000)
        fetch_next_dms(cursor)
    end
  end

  # Request DMs since the given cursor, which represents the last request we made
  # Returns newest first
  def dms_since_cursor(cursor, dms_so_far \\ []) do
    response = fetch_next_dms(cursor)
    dms_so_far = [response.events | dms_so_far]

    case response |> Map.get(:next_cursor) do
      nil ->
        # No further pages, return what we got (sorted newest first) + the last cursor
        sorted_dms = dms_so_far |> List.flatten |> Enum.sort_by(fn d -> (d.created_timestamp |> String.to_integer) * -1 end)
        %{cursor: cursor, dms: sorted_dms}
      next_cursor ->
        # Further pages, request more
        dms_since_cursor(next_cursor, dms_so_far)
    end
  end

  def mark_dms_read(sender_id, dm_id) do
    Logger.info("Marking DM #{dm_id} read for Twitter ID #{sender_id}")
    params = [recipient_id: sender_id, last_read_event_id: dm_id]
    params = ExTwitter.Parser.parse_request_params(params)

    # Need to go lower level here because ExTwitter request tries to parse JSON and this response is no content
    url = ExTwitter.API.Base.request_url("1.1/direct_messages/mark_read.json")
    oauth = ExTwitter.Config.get_tuples
    try do
      ExTwitter.OAuth.request(:post, url, params,
        oauth[:consumer_key], oauth[:consumer_secret], oauth[:access_token], oauth[:access_token_secret])
    rescue
      e ->
        # Sending read receipts is non-critical, so just ignore any errors
        Logger.info("Error when trying to mark DMs read: #{inspect(e)}")
    end
  end

  # Paginated API, this function makes a single call to
  # https://developer.twitter.com/en/docs/twitter-api/tweets/search/api-reference/get-tweets-search-recent
  # Using a bearer token as authorization
  defp fetch_next_tweets(since_id, next_token) do
    url = ExTwitter.API.Base.request_url("2/tweets/search/recent")

    params = [
      # Match replies tagging the bot and exclude retweets
      query: "@CentralTipsBot is:reply -is:retweet",
      max_results: 100,
      "tweet.fields": "author_id,in_reply_to_user_id,created_at"
    ] ++ case since_id do
      nil -> []
      _ -> [since_id: since_id]
    end ++ case next_token do
      nil -> []
      _ -> [next_token: next_token]
    end
    |> ExTwitter.Parser.parse_request_params
    |> URI.encode_query

    url="#{url}?#{params}"
    headers = ["Authorization": "Bearer #{@bearer_token}"]

    {:ok, response} = HTTPoison.get(url, headers)
    case response.status_code do
      200 -> {:ok, response.body |> Jason.decode!}
      429 ->
        # Rate limited
        rate_limit_reset = response.headers |> Map.new |> Map.get("x-rate-limit-reset") |> String.to_integer
        {:rate_limit, rate_limit_reset}
      _ -> {:err, response}
    end
  end

  # Request DMs since the given cursor, which represents the last request we made
  # Returns newest first
  def tweets_to_process_since_id(since_id, next_token \\ nil, tweets_so_far \\ []) do
    case fetch_next_tweets(since_id, next_token) do
      {:ok, response} ->
        meta = Map.get(response, "meta")
        data = Map.get(response, "data", nil) # data not returned when no tweets

        tweets_so_far = case data do
          nil -> tweets_so_far
          _ -> [tweets_so_far | data] # We can always append because later results (using next_token) always get older tweets in order
        end

        case Map.get(meta, "next_token") do
          nil ->
            # No further pages, return what we got
            tweets_so_far |> List.flatten
          next_token ->
            # Further pages, request more
            Logger.info("Fetching more Tweets, since_id: #{since_id}, next_token: #{next_token}")
            tweets_to_process_since_id(since_id, next_token, tweets_so_far)
        end
      {:rate_limit, rate_limit_reset} ->
        # Got a Twitter rate limit, sleep until we can request more
        now = :os.system_time(:second)
        sleep_for_seconds = rate_limit_reset - now + 1
        Logger.info("Got Twitter rate limit, waiting #{sleep_for_seconds} seconds before re-trying")
        :timer.sleep (sleep_for_seconds * 1000)
        tweets_to_process_since_id(since_id, next_token, tweets_so_far)
      {:err, response} ->
        Logger.error("Received unexpected response from Twitter API: #{inspect(response)}")
    end
  end
end
