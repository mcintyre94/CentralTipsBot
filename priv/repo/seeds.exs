# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Centraltipsbot.Repo.insert!(%Centraltipsbot.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Centraltipsbot.{Repo, LastProcessed}

Repo.insert!(%LastProcessed{
  name: "wallet_incoming",
  last_processed: %{}
})

Repo.insert!(%LastProcessed{
  name: "twitter_dms",
  last_processed: %{
    pagination_cursor: nil,
    dm_id: nil
  }
})
