defmodule Hanabi.IRC.Handler do
  alias Hanabi.{User, Channel}
  alias Hanabi.IRC.Message
  require Logger
  use GenServer

  @moduledoc false
  @hostname Application.get_env(:hanabi, :hostname)

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_info({client, %Message{}=msg}, state) do
    dispatch client, msg

    {:noreply, state}
  end

  def handle_call({client, %Message{}=msg}, _from, state) do
    dispatch client, msg

    {:reply, :ok, state}
  end

  def dispatch(client, %Message{}=msg) do
    user = User.get(client)
    case msg.command do
      "NICK" -> User.set_nick(user, msg.middle)
      "USER" -> User.register(:irc, user, msg)
      "QUIT" -> User.quit(user, msg)
      "PING" -> pong(user, msg)
      "JOIN" -> Channel.join(user, msg)
      "NAMES" -> Channel.send_names(user, msg)
      "PART" -> Channel.part(user, msg)
      "PRIVMSG" -> privmsg(user, msg)
      "TOPIC" -> Channel.set_topic(user, msg)
      _ -> Logger.warn "Unknown command : #{msg.command}"
    end
  end

  ###

  def pong(%User{}=user, %Message{}=msg) do
    rpl = %Message{
      prefix: @hostname,
      command: "PONG",
      middle: User.ident_for(user),
      trailing: msg.middle
    }
    User.send user, rpl
  end

  def privmsg(%User{}=user, %Message{}=msg) do
    if msg.middle do
      if String.match?(msg.middle, ~r/^#\S*$/ui) do
        Channel.send_privmsg user, msg
      else
        User.send_privmsg user, msg
      end
    end
  end
end
