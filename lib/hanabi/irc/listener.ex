defmodule Hanabi.IRC.Listener do
  alias Hanabi.{User, IRC}
  require Logger
  use Hanabi.IRC.Numeric
  use GenServer

  @moduledoc false
  @handler Hanabi.IRC.Handler
  @password Application.get_env(:hanabi, :password)

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
    lookup = User.get(client)
    user = if lookup do
      lookup
    else
      new_user = struct(User, %{port: client, key: client})
      User.set(client, new_user)
      new_user
    end

    msg = IRC.parse(data)

    # If a server-wide password is required, it must precede NICK/USER
    if @password && not user.is_pass_validated? do
      # Only process PASS
      if msg.command == "PASS", do: GenServer.call(@handler, {client, msg})

      initial_serve(client)
    else
      # Only process PASS, NICK and USER
      if msg.command in ["PASS", "NICK", "USER"], do: GenServer.call(@handler, {client, msg})

      user = User.get(client) # user was most likely modified
      if IRC.validate(:user, user) do
        Logger.debug "New IRC user : #{User.ident_for(user)}"

        # Greet the user!
        Kernel.send(@handler, {:greet, client})

        send self(), :serve
      else
        # User has not sent through all the right messages yet. Keep listening!
        initial_serve(client)
      end
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
