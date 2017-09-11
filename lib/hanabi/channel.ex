defmodule Hanabi.Channel do
  alias Hanabi.{User, Channel, Registry}
  alias Hanabi.IRC.Message
  use Hanabi.IRC.Numeric

  @hostname Application.get_env(:hanabi, :hostname)
  @table :hanabi_channels # ETS table, see Hanabi.Registry
  @moduledoc """
  Entry point to interact with channels.

  Channels are represented using the following structure :

  ```
  %Hanabi.Channel{
    name: nil,
    relay_to: [:irc, :virtual],
    topic: "",
    users: []
  }
  ```

  *Hanabi* maintains a registry storing all existing channels using their
  names (e.g. : `#hanabi`) as keys. This registry can be accessed using the
  `get/1`, `get_all/0`, `update/2`, `set/2` and `drop/1` methods.
  """

  defstruct name: nil, users: [], topic: "", relay_to: [:irc, :virtual]

  ####
  # Registry access

  @doc """
  Returns the channel structure registered under the identifier `key`.

  If no such identifier is found in the registry, returns `nil`.
  """
  def get(key), do: Registry.get @table, key

  @doc """
  Returns a list containing all the pairs `{key, channel_struct}`.
  """
  def get_all(), do: Registry.dump @table

  @doc """
  Update the values of an existing user struct stored in the registry.

    * `channel` is either the channel's identifier or struct.
    * `value` is a struct changeset, (`topic: "my topic"`, `%{topic:
    "my topic", users: [], ...}`)

  Returns the updated struct or `nil`.
  """
  def update(%Channel{}=channel, change) do
    updated = struct(channel, change)
    if Registry.update(@table, channel.name, updated), do: updated, else: nil
  end
  def update(key, change) do
    channel = Channel.get key
    if channel, do: update(channel, change), else: nil
  end

  @doc """
  Save the `channel` struct in the registry under the given identifier. Any
  existing value will be overwritten.
  """
  def set(key, %Channel{}=channel), do: Registry.set @table, key, channel

  @doc """
  Remove a channel from the registry given its identifier.
  """
  def destroy(%Channel{}=channel), do: Registry.drop @table, channel.name
  def destroy(key), do: Registry.drop @table, key

  @doc false
  def flush_registry, do: Registry.flush @table

  ###

  @doc """
  Send the message `msg` to every user in the channel `channel`.

    * `channel` is a channel's struct or identifier
    * `msg` is a message's struct
  """
  def broadcast(%Channel{}=channel, %Message{}=msg) do
    for user <- channel.users do
      :ok = User.send(user, msg)
    end

    :ok
  end
  def broadcast(channel_name, %Message{}=msg) do
    broadcast Channel.get(channel_name), msg
  end

  ###
  # Specific actions

  @doc """
  Convenience function to send a PRIVMSG to a channel.
  """
  def send_privmsg(%User{}=sender, %Channel{}=channel, content) do
    msg = %Message{
      prefix: User.ident_for(sender),
      command: "PRIVMSG",
      middle: channel.name,
      trailing: content
    }

    Channel.broadcast channel, msg
  end
  def send_privmsg(nil, _, _), do: :err
  def send_privmsg(_, nil, _), do: :err
  def send_privmsg(%User{}=user, channel_name, content) do
    send_privmsg user, Channel.get(channel_name), content
  end
  def send_privmsg(user_key, %Channel{}=channel, content) do
    send_privmsg User.get(user_key), channel, content
  end
  def send_privmsg(user_key, channel_name, content) do
    send_privmsg User.get(user_key), Channel.get(channel_name), content
  end

  @doc """
   Add an user to a channel.

    * `user` is either the user's struct or identifier
    * `channel` is either the channel's struct or identifier. A new channel
  will be created if there is no channel registered under the given identifier.

  Return values :

    * `{:ok, updated_channel}`
    * `{:err, :no_such_user}`
  """
  def add_user(%User{}=user, %Channel{}=channel) do
    channel = Channel.update channel, users: channel.users ++ [user.key]
    User.update user, channels: user.channels ++ [channel.name]

    join_msg = %Message{
      prefix: User.ident_for(user),
      command: "JOIN",
      middle: channel.name
    }
    Channel.broadcast(channel, join_msg)

    {:ok, channel}
  end

  def add_user(nil, _), do: {:err, :no_such_user}
  def add_user(user_key, %Channel{}=channel) do
    add_user(User.get(user_key), channel)
  end
  def add_user(%User{}=user, channel_name) do
    channel = case Channel.get(channel_name) do
      nil ->
        channel = %Channel{name: channel_name}
        Channel.set channel_name, channel
        channel
      channel -> channel
    end
    add_user(user, channel)
  end
  def add_user(user_key, channel_name) do
    add_user(User.get(user_key), channel_name)
  end

  @doc """
  Remove an user from a channel.

    * `user` is either the user's struct or identifier
    * `channel` is either the channel's struct or identifier
    * `part_msg` is a string if specified

  Return values :

    * `{:ok, updated_channel}`
    * `{:err, @err_notonchannel}`
    * `{:err, @err_nosuchchannel}`
    * `{:err, :no_such_user}`

  `@err_notonchannel` and `@err_nosuchchannel` are defined in
  `Hanabi.IRC.Numeric`.
  """
  def remove_user(user, channel, part_msg \\ nil)
  def remove_user(%User{}=user, %Channel{}=channel, part_msg) do
    if (user.key in channel.users) do
      Channel.broadcast channel, %Message{
        prefix: User.ident_for(user),
        command: "PART",
        middle: channel.name,
        trailing: part_msg
      }

      channel = Channel.update channel, users: List.delete(channel.users, user.key)
      _user = User.update user, channels: List.delete(user.channels, channel.name)

      # Returns
      {:ok, channel}
    else
      {:err, @err_notonchannel}
    end
  end
  def remove_user(%User{}=user, channel_name, part_msg) do
    channel = Channel.get(channel_name)
    if channel do
      remove_user(user, channel, part_msg)
    else
      {:err, @err_nosuchchannel}
    end
  end
  def remove_user(nil, _, _), do: {:err, :no_such_user}
  def remove_user(user, channel_name, part_msg) do
    remove_user(User.get(user), channel_name, part_msg)
  end

  @doc """
  Set the topic of a channel.

  * `channel` is either a channel's struct or identifier
  * `topic` is a string
  * `name` is the one who changed the topic. Defaults to the server's hostname

  Return values :

    * `:ok`
    * `:err` if there is no such channel under the given key
  """
  def set_topic(channel, topic, name \\ @hostname)
  def set_topic(%Channel{}=channel, topic, name) do
    if Kernel.is_binary(topic) do
      channel = Channel.update channel, topic: topic

      rpl_topic = %Message{
        prefix: name,
        command: "TOPIC",
        middle: "#{channel.name}",
        trailing: channel.topic
      }
      Channel.broadcast channel, rpl_topic
      :ok
    else
      :err
    end
  end
  def set_topic(nil, _, _), do: :err
  def set_topic(channel, topic, name) do
    set_topic Channel.get(channel), topic, name
  end

  # Get a string constitued of nicknames (separated by spaces) from a list of
  # user identifiers.
  @doc false
  def get_names(userkeys, names \\ nil)
  def get_names([], names), do: names
  def get_names([userkey|tail], names) do
    name = User.get(userkey) |> Map.get(:nick)
    concatenated = if names, do: "#{names} #{name}", else: name
    get_names tail, concatenated
  end
end
