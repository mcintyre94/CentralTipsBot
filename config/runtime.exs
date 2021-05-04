import Config
require Logger

# This file copied from https://fly.io/docs/getting-started/elixir/#runtime-config

Logger.info("Loaded releases.exs")

# Copied from config.exs, for runtime

config :centraltipsbot,
  ecto_repos: [Centraltipsbot.Repo],
  generators: [binary_id: true],
  wallet_watcher: [
    interval: 60_000, # milliseconds
    public_key: "6ritkvkev6qnq933qf96kyn7rnvfyi7ey3kvyrp9f7ipqvtk67yn9iyleti9irne" # deposits wallet public key
  ],
  dm_listener: [
    interval: 60_000 # milliseconds (Twitter limit is 15 req/15 mins)
  ],
  tweet_listener: [
    interval: 10_000 # milliseconds (Twitter limit is 450 req/15 mins)
  ],
  tip_processor: [
    interval: 60_000, # milliseconds
    enable_payments: System.get_env("ENABLE_PAYMENTS", "false"), # Only send real payments if this is true
    cc_api_key: System.get_env("CENTRALIZED_COINS_API_KEY")
  ],
  twitter: [
    bot_twitter_id: "1382976893515862016"
  ]

# Configure Twitter credentials
config :extwitter, :oauth, [
  consumer_key: System.get_env("TWITTER_CONSUMER_KEY"),
  consumer_secret: System.get_env("TWITTER_CONSUMER_SECRET"),
  access_token: System.get_env("TWITTER_ACCESS_TOKEN"),
  access_token_secret: System.get_env("TWITTER_ACCESS_SECRET"),
  bearer_token: System.get_env("TWITTER_BEARER_TOKEN")
]

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  app_name =
    System.get_env("FLY_APP_NAME") ||
      raise "FLY_APP_NAME not available"


  # Uncomment these when we add Phoenix web endpoint
  # config :hello_elixir, HelloElixirWeb.Endpoint,
  #   server: true,
  #   url: [host: "#{app_name}.fly.dev", port: 80],
  #   http: [
  #     port: String.to_integer(System.get_env("PORT") || "4000"),
  #     # IMPORTANT: support IPv6 addresses
  #     transport_options: [socket_opts: [:inet6]]
  #   ],
  #   secret_key_base: secret_key_base

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :centraltipsbot, Centraltipsbot.Repo,
    url: database_url,
    # IMPORTANT: Or it won't find the DB server
    socket_options: [:inet6],
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
