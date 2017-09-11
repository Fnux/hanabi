defmodule Hanabi.User do
  alias Hanabi.{Registry, User, Channel, IRC}
  alias Hanabi.IRC.Message
  use Hanabi.IRC.Numeric

  @table :hanabi_users # ETS table name, see Hanabi.Registry
  @moduledoc """
  Entry point to interact with users.

  Users are represented using the following structure :

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

  *Hanabi* maintains a registry storing every connected user. There are three
  different 'type' of users :
    * `:irc` : the user is directly connected via IRC and identified by its
  TCP session
    * `:virtual` : 'virtual' user defined by the system, its identifier is
  mannualy set with `add/1` ot `add/7`
    * `:void` : same as `:virtual`, exept that no message will be transmitted
  to those users

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
  Update the values of an existing user struct stored in the registry.

    * `user` is either the user's identifier or struct.
    * `value` is a struct changeset, (`nick: "fnux"`, `%{nick:
    "lambda", realname: "Lamb Da", ...}`)
  """
  def update(%User{}=user, value) do
    updated = struct(user, value)
    if Registry.update(@table, user.key, updated), do: updated, else: nil
  end
  def update(key, value) do
    user = User.get key
    if user, do: update(user, value), else: nil
  end

  @doc """
  Save the `user` struct in the registry under the given identifier. Returns
  `false` if the key is already in use.
  """
  def set(key, %User{}=user), do: Registry.set(@table, key, user)

  @doc """
  Remove an user from the registry given its struct or identifier.
  """
  def destroy(%User{}=user), do: Registry.drop @table, user.key
  def destroy(key), do: Registry.drop @table, key

  @doc false
  def flush_registry, do: Registry.flush @table

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
      :irc ->
        IRC.send(user.port, msg)
      :virtual ->
        Kernel.send(user.pid, msg)
        :ok
      :void -> :ok
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
      %User{} -> true
      _ -> false
    end
  end

  ###
  # Specific actions

  @doc """
  Convenience function to send a PRIVMSG to an user.
  """
  def send_privmsg(%User{}=sender, %User{}=receiver, content) do
    msg = %Message{
      prefix: ident_for(sender),
      command: "PRIVMSG",
      middle: receiver.nick,
      trailing: content
    }

    User.send receiver, msg
  end
  def send_privmsg(nil, _, _), do: :err
  def send_privmsg(_, nil, _), do: :err
  def send_privmsg(%User{}=sender, receiver_key, content) do
    send_privmsg sender, User.get(receiver_key), content
  end
  def send_privmsg(sender_key, %User{}=receiver, content) do
    send_privmsg User.get(sender_key), receiver, content
  end
  def send_privmsg(sender_key, receiver_key, content) do
    send_privmsg User.get(sender_key), User.get(receiver_key), content
  end

  @doc """
  Changes the nick of the given user (identifier or struct).

  Return values :
    * `{:err, @err_erroneusnickname}`
    * `{:err, @err_nicknameinuse}`
    * `{:err, :no_such_user"}`
    * `{:ok, new_nickname}`

  `@err_erroneusnickname` and `@err_nicknameinuse` are defined in
  `Hanabi.IRC.Numeric`.
  """
  def change_nick(%User{}=user, new_nickname) do
    case IRC.validate(:nick, new_nickname) do
      {:err, reason} -> {:err, reason}
      {:ok, new_nickname} ->
        notification = %Message{
          prefix: user.nick, # Old nick
          command: "NICK",
          middle: new_nickname
        }

        # Only if the user already have a nickname
        if user.nick, do: User.broadcast(user, notification)

        user = User.update(user, nick: new_nickname)

        {:ok, user}
    end
  end
  def change_nick(nil, _), do: {:err, :no_such_user}
  def change_nick(user_key, new_nickname) do
    change_nick(User.get(user_key), new_nickname)
  end

  @doc """
  Register an user given its struct.

  Return values :
    * `{:err, @err_needmoreparams}`
    * `{:err, @err_alreadyregistered}` : there already is an user with the
  same username
    * `{:err, @err_erroneusnickname}`
    * `{:err, @err_nicknameinuse}`
    * `{:err, :invalid_port}` : `:irc` user but `user.port` is not a port
    * `{:err, :invalid_pid}` : `:virtual` user but `user.pid` is not a pid
    * `{:err, :key_in_use}`
    * `{:ok, identifier}`

  `@err_needmoreparams`, `@err_alreadyregistered`, `@err_erroneusnickname`
  and `@err_nicknameinuse` are defined in `Hanabi.IRC.Numeric`.
  """
  def add(%User{}=user) do
    cond do
      !IRC.validate(:user, user) -> {:err, @err_needmoreparams}
      is_in_use?(:username, user.username) -> {:err, @err_alreadyregistered}
      (user.type == :irc) && !Kernel.is_port(user.port) -> {:err, :invalid_port}
      (user.type == :virtual) && !Kernel.is_pid(user.pid) -> {:err, :invalid_pid}
      true ->
        case IRC.validate(:nick, user.nick) do
          {:err, reason} -> {:err, reason}
          {:ok, _nick} ->
            if User.set(user.key, user) do
              {:ok, user.key}
            else
              {:err, :key_in_use}
            end
        end
    end
  end

  @doc """
  Convenience function to register an user.
  """
  def add(type, key, pid, nick, username, realname, hostname) do
    user = struct User, %{type: type, key: key, pid: pid, nick: nick, username: username,
      realname: realname, hostname: hostname}
    add(user)
  end

  @doc """
  Remove an user from the server.

  * `user` is either the user's struct or identifier
  * `part_msg` is a string if specified
  """
  def remove(user, part_msg \\ nil)
  def remove(%User{}=user, part_msg) do
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
  def remove(nil, _), do: :err
  def remove(user_key, part_msg), do: remove(User.get(user_key), part_msg)
end
