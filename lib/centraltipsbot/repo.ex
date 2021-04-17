defmodule Centraltipsbot.Repo do
  use Ecto.Repo,
    otp_app: :centraltipsbot,
    adapter: Ecto.Adapters.Postgres
end
