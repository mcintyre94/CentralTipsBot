defmodule Centraltipsbot.TweetListenerTest do
  use ExUnit.Case, async: true

  test "parse_text should extract a tip quantity" do
    assert {:ok, 1} = "@thecallummc Can I tag myself? @CentralTipsBot 1cc 👀 "
    assert {:ok, 1.2} = "@thecallummc @CentralTipsBot 1.2"
    assert {:ok, 1000} = "@thecallummc @CentralTipsBot 1,000"
    assert :nil == "@abc I’ve been tweeting about building @CentralTipsBot in Elixir if you’re interested in that!"
    assert {:ok, 100} = "Tipping myself because why not? @CentralTipsBot 100! (let's not do factorial expansions 😃)"
  end
end
