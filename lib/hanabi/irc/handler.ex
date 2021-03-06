defmodule Hanabi.IRC.Handler do
  alias Hanabi.{User, Channel, IRC, IRC.Message}
  require Logger
  use GenServer
  use Hanabi.IRC.Numeric

  @moduledoc false
  @motd_file Application.get_env(:hanabi, :motd)
  @hostname Application.get_env(:hanabi, :hostname)
  @password Application.get_env(:hanabi, :password)
  @authorized_umode_change []

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_info({:greet, client}, state) do
    greet(client)

    {:noreply, state}
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
      "JOIN" -> join(user, msg)
      "LIST" -> list(user, msg)
      "MODE" -> mode(user, msg)
      "MOTD" -> send_motd(user)
      "NAMES" -> names(user, msg)
      "NICK" -> set_nick(user, msg.middle)
      "PART" -> part(user, msg)
      "PASS" -> pass(user, msg)
      "PING" -> pong(user, msg)
      "PRIVMSG" -> privmsg(user, msg)
      "QUIT" -> quit(user, msg)
      "TOPIC" -> topic(user, msg)
      "USER" -> register(user, msg)
      "WHO" -> who(user, msg)
      "WHOIS" -> whois(user, msg)
      _ -> Logger.warn "Unknown command : #{msg.command}"
    end
  end

  ###
  # Internal

  def greet(client) do
    user = User.get(client)

    {:ok, hostname} = :inet.gethostname
    version = "#{Hanabi.app()}-#{Hanabi.version()}"

    network_name = Application.get_env(:hanabi, :network_name)
    created_on = Application.get_env(:hanabi, :network_created_on)
    available_user_modes = List.to_string(User.available_modes)
    available_channel_modes = List.to_string(Channel.available_modes)

    # RPL_WELCOME
    User.send user, %Message{
      prefix: @hostname,
      command: @rpl_welcome,
      middle: user.nick,
      trailing:
        "Welcome to the #{network_name} Network, #{User.ident_for(user)}"
    }

    # RPL_YOURHOST
    User.send user, %Message{
      prefix: @hostname,
      command: @rpl_yourhost,
      middle: user.nick,
      trailing:
        "Your host is #{hostname}, running version #{version}"
    }

    # RPL_CREATED
    User.send user, %Message{
      prefix: @hostname,
      command: @rpl_created,
      middle: user.nick,
      trailing: "This server was created #{created_on}"
    }

    # RPL_MYINFO
    User.send user, %Message{
      prefix: @hostname,
      command: @rpl_myinfo,
      middle: "#{user.nick} #{hostname} #{version} #{available_user_modes} \
      #{available_channel_modes}"
    }

    # Message Of The Day (MOTD)
    Kernel.send(self(), {client, %Message{command: "MOTD"}})
  end

  ###
  # Handling incoming messages

  # JOIN
  def join(%User{}=user, %Message{}=msg) do
    channel_name = msg.middle
    if IRC.validate(:channel, channel_name) do
      channel = case Channel.get(channel_name) do
        nil -> struct(Channel, name: channel_name)
        channel -> channel
      end

      {:ok, channel} = Channel.add_user(user, channel)

      rpl_topic = %Message{
        prefix: @hostname,
        command: @rpl_topic,
        middle: "#{user.nick} #{channel.name}",
        trailing: channel.topic
      }

      User.send user, rpl_topic
      send_names(user, channel)
    else
      err = %Message{
        prefix: @hostname,
        command: @err_nosuchchannel,
        middle: channel_name,
        trailing: "No such channel"
      }
      User.send user, err
    end
  end

  # LIST
  def list(%User{}=user, %Message{}=msg) do
    #RPL_LISTSTART
    User.send user, %Message{
      prefix: @hostname,
      command: @rpl_liststart,
      middle: "Channel",
      trailing: "Users Name"
    }

    #RPL_LIST
    keys = if msg.middle do
      String.split(msg.middle, ",")
    else
      Channel.get_all_keys()
    end

    for key <- keys do
      channel = Channel.get(key)
      cond do
        channel ->
          user_count = Enum.count(channel.users)

          User.send user, %Message{
            command: @rpl_list,
            prefix: @hostname,
            middle: "#{channel.name} #{user_count}",
            trailing: channel.topic
          }
        IRC.validate(:channel, key) ->
          User.send user, %Message{
            command: @err_nosuchnick,
            prefix: @hostname,
            middle: key,
            trailing: "No such nick/channel"
          }
        true ->
          # Invalid channel name, just ignore
          :noop
      end
    end

    #RPL_LISTEND
    User.send user, %Message{
      prefix: @hostname,
      command: @rpl_listend,
      trailing: "End of /LIST"
    }
  end

  # MODE
  def mode(%User{}=user, %Message{}=msg) do
    arguments = String.split(msg.middle)

    target = Enum.at(arguments, 0)
    modechange = Enum.at(arguments, 1)

    [_, change, mode] =
      if !is_nil(modechange) && Regex.match?(~r/^(\+|\-)(\D)$/, modechange) do
        Regex.run(~r/^(\+|\-)(\D)$/, modechange)
      else
        List.duplicate(nil, 3)
      end

    cond do
      is_nil Enum.at(arguments, 0) ->
        User.send user, %Message{
          prefix: @hostname,
          command: @err_needmoreparams,
          middle: "MODE",
          trailing: "Not enough parameters"
        }
      user.nick != target ->
        User.send user, %Message{
          prefix: @hostname,
          command: @err_userdontmatch,
          middle: user.nick,
          trailing: "Cannot change mode for other users"
        }
      Enum.count(arguments) == 1 ->
        User.send user, %Message{
          prefix: @hostname,
          command: @rpl_umodeis,
          middle: "#{user.nick} #{List.to_string(user.modes)}"
        }
      not Enum.member?(User.available_modes, mode) ->
        User.send user, %Message{
          prefix: @hostname,
          command: @err_umodeunknownflag,
          middle: user.nick,
          trailing: "Unknown MODE flag"
        }
      not Enum.member?(@authorized_umode_change, modechange) -> :noop #ignore
      true ->
        {:ok, _modes} = case change do
          "+" -> User.add_mode(user, mode)
          "-" -> User.remove_mode(user, mode)
        end

        User.send user, %Message{
          prefix: user.nick,
          command: "MODE",
          middle: target,
          trailing: modechange
        }
    end
  end

  # MOTD
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

  # NAMES
  def names(%User{}=user, %Message{}=msg) do
    channel = Channel.get(msg.middle)
    send_names(user, channel)
  end
  defp send_names(%User{}=user, %Channel{}=channel) do
      names = Channel.get_names(channel.users)
      rpl_namreply = %Message{
        prefix: @hostname,
        command: @rpl_namreply,
        middle: "#{user.nick} = #{channel.name}",
        trailing: names
      }

      rpl_endofnames = %Message{
        prefix: @hostname,
        command: @rpl_endofnames,
        middle: "#{user.nick} #{channel.name}",
        trailing: "End of /NAMES list"
      }

      User.send user, [rpl_namreply, rpl_endofnames]
  end

  # NICK
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

  # PART
  def part(%User{}=user, %Message{}=msg) do
    if String.match?(msg.middle, ~r/^(#\w*(,#\w*)?)*$/ui) do
      channel_names = String.split(msg.middle, ",")

      for channel_name <- channel_names do
        case Channel.remove_user(user, channel_name, msg.trailing) do
          {:err, @err_notonchannel} ->
            err = %Message{
              prefix: @hostname,
              command: @err_notonchannel,
              middle: channel_name,
              trailing: "You're not on that channel"
            }
            User.send user, err
          {:err, @err_nosuchchannel} ->
            err = %Message{
              prefix: @hostname,
              command: @err_nosuchchannel,
              middle: channel_name,
              trailing: "No such channel"
            }
            User.send user, err
          _ -> :noop
        end
      end
    else
      err = %Message{
        prefix: @hostname,
        command: @err_needmoreparams,
        middle: "PART",
        trailing: "Not enough parameters"
      }
      User.send user, err
    end
  end

  # PASS
  def pass(%User{}=user, %Message{}=msg) do
    if msg.middle do
      validation_status = (msg.middle == @password)
      User.update(user, is_pass_validated?: validation_status)
    else
      err = %Message{
        prefix: @hostname,
        command: @err_needmoreparams,
        middle: "PART",
        trailing: "Not enough parameters"
      }
      User.send user, err
    end
  end

  # PING / PONG
  def pong(%User{}=user, %Message{}=msg) do
    rpl = %Message{
      prefix: @hostname,
      command: "PONG",
      middle: User.ident_for(user),
      trailing: msg.middle
    }
    User.send user, rpl
  end

  # PRIVMSG
  def privmsg(%User{}=user, %Message{}=msg) do
    if msg.middle do
      if String.match?(msg.middle, ~r/^#\S*$/ui) do
        channel_privmsg user, msg
      else
        user_privmsg user, msg
      end
    end
  end
  defp user_privmsg(%User{}=sender, %Message{}=msg) do
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
  defp channel_privmsg(%User{}=sender, %Message{}=msg) do
    channel_name = msg.middle
    channel = Channel.get channel_name

    if channel do
      privmsg = %Message{
        prefix: User.ident_for(sender),
        command: "PRIVMSG",
        middle: channel_name,
        trailing: msg.trailing
      }

      # Remove sender from receivers !
      channel = struct(channel, users: List.delete(channel.users, sender.key))
      Channel.broadcast channel, privmsg
    else
      err = %Message{
        prefix: @hostname,
        command: @err_nosuchnick,
        middle: "#{sender.nick} #{channel_name}",
        trailing: "No such nick/channel"
      }
      User.send sender, err
    end
  end

  # QUIT
  def quit(%User{}=user, %Message{}=msg) do
    User.remove user, msg.trailing
  end

  # TOPIC
  def topic(%User{}=user, %Message{}=msg) do
    channel_name = msg.middle
    channel = Channel.get channel_name

    if (channel && user.key in channel.users) do
      Channel.set_topic(channel, msg.trailing, user.nick)
    else
      err = %Message{
        prefix: @hostname,
        command: @err_notonchannel,
        middle: "#{user.nick} #{channel_name}",
        trailing: "You're not on that channel"
      }
      User.send user, err
    end
  end

  # USER
  def register(%User{}=user, %Message{}=msg) do
    regex = ~r/^(\w*)\s(\w*)\s(\S*)$/ui
    if String.match?(msg.middle, regex) && msg.trailing do
      [_, username, _hostname, _servername]
      = Regex.run(regex, msg.middle)

      realname = msg.trailing
      hostname = IRC.resolve_hostname(user.port)

      changeset = %{
        username: username, realname: realname, hostname: hostname
      }

      User.update(user, changeset)
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

  # WHO
  def who(%User{}=user, %Message{}=msg) do
    :not_yet_implemented
  end

  # WHOIS
  def whois(%User{}=user, %Message{}=msg) do
    if msg.middle do
      # Only handle the first one
      nick = msg.middle |> String.split(",") |> List.first
      lookup = User.get_by(:nick, nick)

      if lookup do
        rpl_whoisuser = %Message{
          prefix: @hostname,
          command: @rpl_whoisuser,
          middle: "#{lookup.nick} #{lookup.username} #{lookup.hostname} *",
          trailing: lookup.realname
        }
        rpl_endofwhois = %Message{
          prefix: @hostname,
          command: @rpl_endofwhois,
          middle: lookup.nick,
          trailing: "End of /WHOIS list"
        }
        User.send user, [rpl_whoisuser, rpl_endofwhois]
      else
        err = %Message{
          prefix: @hostname,
          command: @err_nosuchnick,
          middle: nick,
          trailing: "No such nick/channel"
        }
        User.send user, err
      end
    else
      err = %Message{
        prefix: @hostname,
        command: @err_nonicknamegiven,
        trailing: "No nickname given"
      }
      User.send user, err
    end
  end
end
