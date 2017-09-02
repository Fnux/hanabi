defmodule Hanabi.IRC.Supervisor do
  use Supervisor

  @moduledoc false

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(Hanabi.IRC.Listener, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  def pop(client) do
    Supervisor.start_child(__MODULE__, [client])
  end

  def drop(client) do
    Supervisor.terminate_child(__MODULE__, client)
  end
end
