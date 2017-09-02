defmodule Hanabi.IRC.Endpoint do
  alias Hanabi.IRC
  require Logger

  @moduledoc false

  # Start TCP socket
  def accept(port \\ 6667) do
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      { :ok, socket } ->
        Logger.info "Hanabi is up and running ! Port: #{port}"
        loop_acceptor(socket)
      { :error, :eaddrinuse } ->
        Logger.error "Address already in use."
        System.halt(1)
    end
  end

  # Accept clients
  defp loop_acceptor(socket) do
    { :ok, client } = :gen_tcp.accept(socket)

    {status, pid} = IRC.Supervisor.pop(client)
    if status == :ok do
      :ok = :gen_tcp.controlling_process(client, pid)
    else
      Logger.error "Unable to start listener. Connexion ignored."
    end

    loop_acceptor(socket)
  end
end
