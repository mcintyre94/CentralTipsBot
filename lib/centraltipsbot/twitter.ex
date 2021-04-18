defmodule Centraltipsbot.Twitter do
  require Logger

  # Paginated API, this function makes a single call to
  # https://developer.twitter.com/en/docs/twitter-api/v1/direct-messages/sending-and-receiving/api-reference/list-events
  defp fetch_next_dms(cursor) do
    try do
      params = [count: 50] ++ case cursor do
        nil -> []
        _ -> [cursor: cursor]
      end
      params = ExTwitter.Parser.parse_request_params(params)
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
end
