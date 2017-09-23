# Hanabi

Hanabi is a (work in progress) IRC server designed to build bridges between
services.

Since Hanabi is an IRC server, messages and errors are designed to match the
definitions of the IRC specification
([RFC1459](https://tools.ietf.org/html/rfc1459)) : see `Hanabi.IRC.Message` for
message structures and `Hanabi.IRC.Numeric` for reply/error codes. Most of
the interactions with this library are done via the `Hanabi.User` and
`Hanabi.Channel` modules.

## Useful links

  * Documentation [on hexdocs.pm](https://hexdocs.pm/hanabi/readme.html).
  * Changelog [on github.com](https://github.com/Fnux/hanabi/blob/master/CHANGELOG.md).
  * Internet Relay Chat Protocol : [RFC1459](https://tools.ietf.org/html/rfc1459),
    [RFC2811](https://tools.ietf.org/html/rfc2811),
    [modern.ircdocs.horse](https://modern.ircdocs.horse/)
  * Parts of the IRC-related code were inspired by
[radar/elixir-irc](https://github.com/radar/elixir-irc).

## Configuration

In order to use this library, you must add `hanabi` to your list of depenencies
in `mix.exs` :

```elixir
def deps do
  [
    {:hanabi, "~> 0.1.0"}
  ]
end
```

You also have to add the following to your `config/config.exs` file :

```
config :hanabi, port: 6667,
                hostname: "my.awesome.hostname",
                motd: "/path/to/motd.txt"
                # server-wide password (PASS) if set
                # , password: "mypassword"
```

## Examples

Here are a few basic example. Feel free to ask for more examples
[here](https://github.com/Fnux/hanabi/) !

### Sending a private message to an user/channel

```elixir
# Sending to an user
iex> receiver = Hanabi.User.get_by(:nick, "fnux")
%Hanabi.User{channels: ["#test"], hostname: 'localhost', key: #Port<0.5044>,
 nick: "fnux", pid: nil, port: #Port<0.5044>, realname: "realname", type: :irc,
 username: "fnux"}

iex> sender = Hanabi.User.get_by(:nick, "sender")
# ...

###
# Using the helper
iex> Hanabi.User.send_privmsg sender, receiver, "Hello fnux! How are you?"
:ok

###
# Manually
iex> msg = %Hanabi.IRC.Message{prefix: Hanabi.User.ident_for(sender),
command: "PRIVMSG", middle: receiver.nick, trailing: "Hello fnux! How are you?"}
# ...

iex> Hanabi.User.send receiver, msg
:ok
```

```elixir
# Sending to a channel
iex> user = Hanabi.User.get_by(:nick, "fnux")
%Hanabi.User{channels: ["#test"], hostname: 'localhost', key: #Port<0.5044>,
 nick: "fnux", pid: nil, port: #Port<0.5044>, realname: "realname", type: :irc,
 username: "fnux"}

###
# Using the helper
iex> Hanabi.Channel.send_privmsg sender, "#test", "Hi there!"
:ok

###
# Manually
iex> msg = %Hanabi.IRC.Message{prefix: Hanabi.User.ident_for(sender),
command: "PRIVMSG", middle: "#test", trailing: "Hi there!"}
# ...

iex> Hanabi.Channel.broadcast "#test", msg
:ok
```

### Simple handling of a virtual user

```elixir
defmodule MyApp.IrcUser do
  alias Hanabi.User
  use GenServer

  @user %User{key: :default, type: :virtual, nick: "default",
  username: "default", realname: "Default User", hostname: "localhost"}

  def start_link() do
    GenServer.start_link(__MODULE__, nick)
  end

  def init(nick) do
    # register itself as the `default` user
    user = struct(@user, pid: self())
    {:ok, user.key} = User.add(user)
  end

  def handle_info(%Message{}=msg, state) do
    # msg is a message's struct as defined in Hanabi.IRC.Message :
    # %Hanabi.IRC.Message{prefix: "sender!~sender@localhost",
    # command: "PRIVMSG", middle: "default",
    # trailing: "Hi! How are you?"}
 
    # do stuff

    {:noreply, state}
  end

  # catch-all used for debugging
  def handle_info(msg, state) do
    IO.inspect msg

    {:noreply, state}
  end
end
```
