defmodule Hanabi.Channel do
  alias Hanabi.{User, Channel, IRC, Registry}
  alias Hanabi.IRC.Message
  use Hanabi.IRC.Numeric

  @hostname Application.get_env(:hanabi, :hostname)
  @table :hanabi_channels # ETS table, see Hanabi.Registry
  @moduledoc """
  Entry point to interact with channels. This module define a structure to
  represent them :

  ```
  %Hanabi.Channel{
    name: nil,
    relay_to: [:irc, :virtual],
    topic: "",
    users: []
  }
  ```

  *Hanabi* maintains a registry storing all existing channels and using their
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
  """
  def update(%Channel{}=channel, change) do
    updated = struct(channel, change)
    if Registry.set(@table, channel.name, updated), do: updated, else: nil
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
  def drop(key), do: Registry.drop @table, key

  ###

  @doc """
  Send the message `msg` to every user in the channel `channel`.

  Both `channel` and `msg` are represented by their respective struct.
  """
  def broadcast(%Channel{}=channel, %Message{}=msg) do
    for user <- channel.users do
      User.send user, msg
    end
  end

  ###
  # Specific actions

  @doc false
  def join(%User{}=user, %Message{}=msg) do
    channel_name = msg.middle
    if IRC.validate(:channel, channel_name) == :ok do
      channel = case Channel.get(channel_name) do
        nil -> struct(Channel, name: channel_name)
        channel -> channel
      end

      channel = Channel.add_user(user, channel)

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

  # Get a string constitued of nicknames (separated by spaces) from a list of
  # user identifiers.
  defp get_names(userkeys, names \\ nil)
  defp get_names([], names), do: names
  defp get_names([userkey|tail], names) do
    name = User.get(userkey) |> Map.get(:nick)
    concatenated = if names, do: "#{names} #{name}", else: name
    get_names tail, concatenated
  end

  @doc false
  def send_names(%User{}=user, %Message{}=msg) do
    channel = Channel.get(msg.middle)
    send_names(user, channel)
  end

  @doc false
  def send_names(%User{}=user, %Channel{}=channel) do
      names = get_names(channel.users)
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

  @doc """
   Add an user to a channel.

    * `user` is either the user's struct or identifier
    * `channel` is either the channel's struct or identifier

  If the user is indeed added to the channel, an updated struct (of the channel)
  is returned. If there's something wrong (unable to find matching items in
  the registries), `err` is returned.
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

    channel
  end

  def add_user(nil, _), do: :err
  def add_user(_, nil), do: :err
  def add_user(u, %Channel{}=c), do: add_user(User.get(u), c)
  def add_user(%User{}=u, c), do: add_user(u, Channel.get(c))
  def add_user(u, c), do: add_user(User.get(u), Channel.get(c))

  @doc false
  def part(%User{}=user, %Message{}=msg) do
    if String.match?(msg.middle, ~r/^(#\w*(,#\w*)?)*$/ui) do
      channel_names = String.split(msg.middle, ",")

      for channel_name <- channel_names do
        case Channel.remove_user(user, channel_name, msg.trailing) do
          {:err, code, explanation} ->
            err = %Message{
              prefix: @hostname,
              command: code,
              middle: channel_name,
              trailing: explanation
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

  @doc """
  Remove an user from a channel.

    * `user` is either the user's struct or identifier
    * `channel` is either the channel's struct or identifier
    * `part_msg` is a string if specified

    Returns `{:ok, updated_user_struct, updated_channel_struct}` if the user
    is removed and `{:err, code, reason}` otherwise.
  """
  def remove_user(user, channel, part_msg \\ nil)
  def remove_user(%User{}=user, %Channel{}=channel, part_msg) do
    if (user.key in channel.users) do
      channel = Channel.update channel, users: List.delete(channel.users, user.key)
      user = User.update user, channels: List.delete(user.channels, channel.name)

      Channel.broadcast channel, %Message{
        prefix: User.ident_for(user),
        command: "PART",
        middle: channel.name,
        trailing: part_msg
      }

      # Returns
      {:ok, user, channel}
    else
      {:err, @err_notonchannel, "You're not on that channel"}
    end
  end
  def remove_user(%User{}=user, channel_name, part_msg) do
    channel = Channel.get(channel_name)
    if channel do
      remove_user(user, channel, part_msg)
    else
      {:err, @err_nosuchchannel, "No such channel"}
    end
  end
  def remove_user(user, channel_name, part_msg) do
    remove_user(User.get(user), channel_name, part_msg)
  end
  def remove_user(nil, _, _), do: {:err, nil, "No such user"}

  @doc false
  def send_privmsg(%User{}=sender, %Message{}=msg) do
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

  @doc """
  Set the topic of a channel.

  * `channel` is either a channel's struct or identifier
  * `topic` is a string

  Returns `:ok` or `:err`.
  """
  def set_topic(%Channel{}=channel, topic) do
    if Kernel.is_binary(topic) do
      channel = Channel.update channel, topic: topic

      rpl_topic = %Message{
        prefix: @hostname,
        command: "TOPIC",
        middle: "#{channel.name}",
        trailing: channel.topic
      }
      IO.inspect rpl_topic
      Channel.broadcast channel, rpl_topic
      :ok
    else
      :err
    end
  end
  def set_topic(nil, _), do: :err
  def set_topic(%User{}=user, %Message{}=msg) do
    channel_name = msg.middle
    channel = Channel.get channel_name

    if (channel && user.key in channel.users) do
      channel = Channel.update channel, topic: msg.trailing
      rpl_topic = %Message{
        prefix: @hostname,
        command: "TOPIC",
        middle: "#{user.nick} #{channel.name}",
        trailing: channel.topic
      }
      Channel.broadcast channel, rpl_topic
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
  def set_topic(channel, topic), do: set_topic Channel.get(channel), topic
end
