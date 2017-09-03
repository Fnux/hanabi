defmodule Hanabi.IRC.Handler do
  alias Hanabi.{User, Channel, IRC, IRC.Message}
  require Logger
  use GenServer
  use Hanabi.IRC.Numeric

  @moduledoc false
  @motd_file Application.get_env(:hanabi, :motd)
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
      "NICK" -> set_nick(user, msg.middle)
      "USER" -> register(user, msg)
      "QUIT" -> quit(user, msg)
      "PING" -> pong(user, msg)
      "MOTD" -> send_motd(user)
      "JOIN" -> Channel.join(user, msg)
      "NAMES" -> Channel.send_names(user, msg)
      "PART" -> Channel.part(user, msg)
      "PRIVMSG" -> privmsg(user, msg)
      "TOPIC" -> Channel.set_topic(user, msg)
      "MODE" -> :not_implemented # @TODO
      "WHO" -> :not_implemented # @TODO
      _ -> Logger.warn "Unknown command : #{msg.command}"
    end
  end

  ###

  def set_nick(%User{}=user, nick) do
    case User.change_nick(user, nick) do
      {:err, @err_erroneusnickname} ->
        err = %Message{
          prefix: @hostname,
          command: @err_erroneusnickname,
          middle: user.nick,
          trailing: "Erroneus nickname"
        }
        User.send user, err
      {:err, @err_nicknameinuse} ->
        err = %Message{
          prefix: @hostname,
          command: @err_nicknameinuse,
          middle: user.nick,
          trailing: "Nickname is already in use"
        }
        User.send user, err
        :err
      _ -> :noop
    end
  end

  def quit(%User{}=user, %Message{}=msg) do
    User.remove user, msg.trailing
  end

  def send_motd(%User{}=user) do
    if File.exists?(@motd_file) do
      lines = File.stream!(@motd_file) |> Stream.map(&String.trim/1)

      #RPL_MOTDSTART
      User.send user, %Message{
        prefix: @hostname,
        command: @rpl_motdstart,
        middle: user.nick,
        trailing: "- #{@hostname} Message of the day - "
      }

      #RPL_MOTD
      for line <- lines do
      User.send user, %Message{
          command: @rpl_motd,
          prefix: @hostname,
          middle: user.nick,
          trailing: "- " <> line
        }
      end

      #RPL_ENDOFMOTD
      User.send user, %Message{
        prefix: @hostname,
        command: @rpl_endofmotd,
        middle: user.nick,
        trailing: "End of /MOTD command"
      }
    else
      User.send user, %Message{
        prefix: @hostname,
        command: @err_nomotd,
        middle: user.nick,
        trailing: "MOTD File is missing"
      }
    end
  end

  def register(%User{}=user, %Message{}=msg) do
    regex = ~r/^(\w*)\s(\w*)\s(\S*)$/ui
    if String.match?(msg.middle, regex) && msg.trailing do
      [_, username, _hostname, _servername]
      = Regex.run(regex, msg.middle)

      realname = msg.trailing
      hostname = IRC.resolve_hostname(user.port)

      user = struct user, %{
        username: username, realname: realname, hostname: hostname
      }

      User.add(user)
    else
      err = %Message{
        prefix: @hostname,
        command: @err_needmoreparams,
        middle: "USER",
        trailing: "Not enough parameters"
      }
      User.send user, err
    end
  end

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
        user_privmsg user, msg
      end
    end
  end

  def user_privmsg(%User{}=sender, %Message{}=msg) do
    recipient_nick = msg.middle
    recipient = User.get_by(:nick, recipient_nick)

    if recipient do
      privmsg = %Message{
        prefix: User.ident_for(sender),
        command: "PRIVMSG",
        middle: recipient_nick,
        trailing: msg.trailing
      }
      User.send recipient, privmsg
    else
      err = %Message{
        prefix: @hostname,
        command: @err_nosuchnick,
        middle: "#{sender.nick} #{recipient_nick}",
        trailing: "No such nick/channel"
      }
      User.send sender, err
    end
  end
end
