defmodule Hanabi do
  import Supervisor.Spec

  @moduledoc false
  @port Application.get_env :hanabi, :port
  @app Mix.Project.config[:app]
  @version Mix.Project.config[:version]

  ###

  def app(), do: @app
  def version(), do: @version

  ###

  def start(), do: start(nil, nil)
  def start(_type, _args) do
    Supervisor.start_link(__MODULE__, :ok, [])
  end

  def init(_) do
    # Supervisor
    children = [
      worker(Hanabi.Registry, [:hanabi_users], [restart: :permanent, id: UserRegistry]),
      worker(Hanabi.Registry, [:hanabi_channels], [restart: :permanent, id: ChannelRegistry]),
      worker(Hanabi.IRC.Handler, [], [restart: :permanent]),
      supervisor(Hanabi.IRC.Supervisor, [], [restart: :permanent]),
      worker(Task, [Hanabi.IRC.Endpoint, :accept, [@port]], restart: :permanent),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
