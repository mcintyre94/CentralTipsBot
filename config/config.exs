# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :centraltipsbot,
  ecto_repos: [Centraltipsbot.Repo],
  generators: [binary_id: true],
  wallet_watcher: [
    interval: 10_000, # milliseconds
    public_key: "6ritkvkev6qnq933qf96kyn7rnvfyi7ey3kvyrp9f7ipqvtk67yn9iyleti9irne" # deposits wallet public key
  ],
  dm_listener: [
    interval: 60_000, # milliseconds (Twitter limit is 15 req/15 mins)
    bot_twitter_id: "1382976893515862016"
  ]

# Configures the endpoint
config :centraltipsbot, CentraltipsbotWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "sdB3K1AXv8tcs9Uf/+niA4V8gQ1N5UYu+GV+52+GFqTx/UbzjFES38MLScYtsFzB",
  render_errors: [view: CentraltipsbotWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Centraltipsbot.PubSub,
  live_view: [signing_salt: "vmAFpat4"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Twitter credentials
config :extwitter, :oauth, [
  consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
  consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET"),
  access_token: System.get_env("TWITTER_ACCESS_TOKEN"),
  access_token_secret: System.get_env("TWITTER_ACCESS_SECRET"),
  bearer_token: System.get_env("TWITTER_BEARER_TOKEN")
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
