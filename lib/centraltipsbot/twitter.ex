defmodule Centraltipsbot.Twitter do
  require Logger

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
  def dms_since_cursor(cursor, dms_so_far \\ []) do
    response = fetch_next_dms(cursor)
    dms_so_far = [response.events | dms_so_far]

    case response |> Map.get(:next_cursor) do
      nil ->
        # No further pages, return what we got + the last cursor
        %{cursor: cursor, dms: dms_so_far |> List.flatten }
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
end
