defmodule Centraltipsbot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Centraltipsbot.Repo,
      # Start the Telemetry supervisor
      CentraltipsbotWeb.Telemetry,
      # Start the PubSub system
      # Add this when we want it!
      # {Phoenix.PubSub, name: Centraltipsbot.PubSub},
      # Start the wallet watcher service
      {Centraltipsbot.WalletWatcher, :ok},
      # Start the DM listener service
      {Centraltipsbot.DMListener, :ok},
      # Start the Tweet listener service
      {Centraltipsbot.TweetListener, :ok},
      # Start the Tip processor service
      {Centraltipsbot.TipProcessor, :ok},
      # Start the Endpoint (http/https)
      CentraltipsbotWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Centraltipsbot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CentraltipsbotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
