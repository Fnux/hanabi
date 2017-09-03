defmodule Hanabi.IRC.Listener do
  alias Hanabi.{User, IRC, IRC.Message}
  require Logger
  use Hanabi.IRC.Numeric
  use GenServer

  @moduledoc false
  @handler Hanabi.IRC.Handler

  def start_link(client) do
    GenServer.start_link(__MODULE__, client)
  end

  def init(client) do
    send self(), :initial_serve

    {:ok, client}
  end

  def handle_info(:initial_serve, client) do
    initial_serve(client)

    {:noreply, client}
  end

  def handle_info(:serve, client) do
    serve(client)

    {:noreply, client}
  end

  def terminate(reason, client) do
    unless reason == :normal, do: Logger.warn "Terminating listener : #{reason}"
    User.remove(client, "Connection closed by client")
  end

  ###

  # Handles initial connection handshake : PASS, USER, NICK messages
  defp initial_serve(client) do
    case :gen_tcp.recv(client, 0) do
      { :ok, data } -> initial_handle(client, data)
      { :error, :closed } ->
        Logger.debug "Connection closed by client."
        Kernel.exit(:normal)
    end
  end

  defp initial_handle(client, data) do
    # Însert a new user in the registry if it does not exist yet
    unless User.get(client) do
      User.set(client, struct(User, %{port: client, key: client}))
    end

    msg = IRC.parse(data)

    case msg.command do
      "CAP" -> :not_implemented # client capability negotiation extension, IRCv3.x
      "PASS" -> :not_implemented # ignored
      "NICK" -> GenServer.call(@handler, {client, msg})
      "USER" -> GenServer.call(@handler, {client, msg})
      _ -> Logger.debug "Ignored command (initial serve) : #{msg.command}"
    end

    user = User.get(client) # user was most likely modified
    if IRC.validate(:user, user) do
      Logger.debug "New IRC user : #{User.ident_for(user)}"

      # send MOTD
      Kernel.send(
        @handler, {client, %Message{command: "MOTD"}}
      )

      send self(), :serve
    else
      # User has not sent through all the right messages yet.
      # Keep listening!
      initial_serve(client)
    end
  end

  # Get new inputs
  defp serve(client) do
    case :gen_tcp.recv(client, 0) do
      { :ok, data } ->
        msg = IRC.parse(data)
        Kernel.send @handler, {client, msg}
        serve(client)
      { :error, :closed } ->
        Logger.debug "Connection closed by client."
        Kernel.exit(:normal)
    end
  end
end
