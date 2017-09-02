defmodule Hanabi.User do
  alias Hanabi.{Registry, User, Channel, IRC}
  alias Hanabi.IRC.Message
  use Hanabi.IRC.Numeric

  @table :hanabi_users # ETS table name, see Hanabi.Registry
  @hostname Application.get_env(:hanabi, :hostname)
  @motd_file Application.get_env(:hanabi, :motd)
  @moduledoc """
  Entry point to interact with users. This module define a structure
  to represent them :

  ```
  %Hanabi.User{
    channels: [],
    hostname: nil,
    key: nil,
    nick: nil,
    pid: nil,
    port: nil,
    realname: nil,
    type: :irc,
    username: nil
  }
  ```

  *Hanabi* maintains a registry storing every connected user. Depending of the
  type of the user (`:irc` or `:virtual`), their identifier may differ :
    * `:irc` : the user is directly connected via IRC, its key is the port
  identifier of its TCP session
    * `:virtual` : 'virtual' user defined by the system, the key @TODO

  The registry can be accessed using the `get/1`, `get_all/0`, `update/2`,
  `set/2` and `destroy/1` methods.
  """

  defstruct key: nil,
    nick: nil,
    username: nil,
    realname: nil,
    hostname: nil,
    type: :irc,
    port: nil,
    pid: nil,
    channels: []

  ####
  # Registry access

  @doc """
  Returns the user structure registered under the identifier `key`.

  If no such identifier is found in the registry, returns `nil`.
  """
  def get(key), do: Registry.get @table, key

  @doc """
  Returns a list containing all the pairs `{key, user_struct}`.
  """
  def get_all(), do: Registry.dump(@table)

  @doc """
  Find the first user matching the pair field/value
  (e.g. `get_by(:nick, "fnux")`). Be careful with this method since it can be
  highly inefficient for a large set of users.
  """
  def get_by(field, value) do
    result = Enum.find(get_all(), fn([{_,user}]) -> Map.get(user, field) == value end)
    if result do
      {_key, user} = List.first(result)
      user
    else
      nil
    end
  end

  @doc """
  Update values of an existing user struct stored in the registry.

    * `user` is either the user's identifier (= key) or struct.
    * `value` is a struct changeset, something like `nick: "fnux` or `%{nick:
    "lambda", realname: "Lamb Da", ...}`
  """
  def update(%User{}=user, value) do
    updated = struct(user, value)
    if Registry.set(@table, user.key, updated), do: updated, else: nil
  end
  def update(key, value) do
    user = User.get key
    if user, do: update(user, value), else: nil
  end

  @doc """
  Save the `user` struct in the registry under the `key` identifier. Any
  existing value will be overwritten.
  """
  def set(key, %User{}=user) do
    case Registry.set(@table, key, user) do
      true -> user
      _ -> nil
    end
  end

  @doc """
  Remove an user from the registry given its struct or identifier.
  """
  def destroy(%User{}=user), do: Registry.drop @table, user.key
  def destroy(key), do: Registry.drop @table, key

  ###

  @doc """
  Sends one or multiple messages to the given user.

    * `user` is either the user's identifier or its struct
    * `msg` is either a single message struct or a list of them
  """
  def send(%User{}, []), do: :noop
  def send(%User{}=user, [%Message{}=msg|tail]) do
    User.send user, msg
    User.send user, tail
  end
  def send(%User{}=user, %Message{}=msg) do
    case user.type do
      :irc -> IRC.send(user.port, msg)
      :virtual -> Kernel.send(user.pid, msg)
    end
  end
  def send(userkey, %Message{}=msg) do
    user = User.get(userkey)
    if user, do: User.send(user, msg), else: :err
  end

  @doc """
  Sends a message to the user and to any channel containeg the user.
    * `user` is either the user's identifier or its struct
    * `msg` is a single message struct
  """
  def broadcast(%User{}=user, %Message{}=msg) do
    User.send user, msg
    for channel <- user.channels do
      Channel.broadcast(channel, msg)
    end
  end
  def broadcast(key, %Message{}=msg) do
    user = User.get(key)
    broadcast(user, msg)
  end

  ###
  # Utils

  @doc """
  Generate an user's identity given its struct.

  ## Example

  ```
  iex> user = %Hanabi.User{channels: [], hostname: 'localhost', key: #Port<0.8947>,
    nick: "fnux", pid: nil, port: #Port<0.8947>, realname: "realname", type: :irc,
    username: "fnux"}
  iex> Hanabi.User.ident_for user
  "fnux!~fnux@localhost"
  ```
  """
  def ident_for(%User{}=user) do
    username = String.slice(user.username, 0..7)
    "#{user.nick}!~#{username}@#{user.hostname}"
  end

  @doc """
  Check if there is an user which has the value `value` in the  field `field`.

  Be careful, this method may be highly innificient with large sets.

  ## Example

  ```
  iex> Hanabi.User.is_in_use(:nick, "nonexisting")
  false
  iex> Hanabi.User.is_in_use(:nick, "existing")
  true
  ```
  """
  def is_in_use?(field, value) do
    case get_by(field, value) do
      {:ok, _} -> true
      _ -> false
    end
  end

  ###
  # Specific actions

  def set_nick(%User{}=user, nick) do
    case IRC.validate(:nick, nick) do
      @err_erroneusnickname ->
        err = %Message{
          prefix: @hostname,
          command: @err_erroneusnickname,
          middle: user.nick,
          trailing: "Erroneus nickname"
        }
        User.send user, err
      @err_nicknameinuse ->
        err = %Message{
          prefix: @hostname,
          command: @err_nicknameinuse,
          middle: user.nick,
          trailing: "Nickname is already in use"
        }
        User.send user, err
      :ok ->
        User.update(user, nick: nick)

        rpl = %Message{
          prefix: user.nick, # Old nick
          command: "NICK",
          middle: nick # New nick
        }

        # Only if the user already have a nickname
        if user.nick, do: User.broadcast user, rpl
    end
  end

  def register(:irc, %User{}=user, %Message{}=msg) do
    regex = ~r/^(\w*)\s(\w*)\s(\S*)$/ui
    if String.match?(msg.middle, regex) && msg.trailing do
      [_, username, _hostname, _servername]
      = Regex.run(regex, msg.middle)

      realname = msg.trailing
      hostname = IRC.resolve_hostname(user.port)

      register :irc, user, username, hostname, realname
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
  def register(:irc, user, username, hostname, realname) do
    unless is_in_use?(:username, username) do
      User.update(user, %{username: username,
        realname: realname,
        hostname: hostname})
      else
      err = %Message{
        prefix: @hostname,
        command: @err_alreadyregistered,
        middle: user.nick,
        trailing: "You may not reregister"
      }
      User.send user, err
    end
  end

  def send_privmsg(%User{}=sender, %Message{}=msg) do
    recipient_nick = msg.middle
    recipient = User.get_by(:nick, recipient_nick)

    if recipient do
      privmsg = %Message{
        prefix: ident_for(sender),
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

  @doc """
  Remove an user from the server.

    * `user` is either the user's struct or identifier
    * `part_msg` is a string if specified
  """
  def quit(user, part_msg \\ nil)
  def quit(%User{}=user, %Message{}=msg) do
    quit user, msg.trailing
  end

  def quit(%User{}=user, part_msg) do
    Enum.each user.channels, fn(channel) ->
      Channel.remove_user(user, channel, part_msg)
    end

    # Destroy user
    User.destroy(user)

    # Close connection.
    if (user.type == :irc) && Port.info(user.port) do
      Port.close(user.port)
    end
  end
  def quit(nil, _), do: :err
  def quit(user, part_msg), do: quit User.get(user), part_msg
end
