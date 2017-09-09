# Hanabi

Hanabi is a (work in progress) IRC server designed to build bridges between
services.

## Useful links

  * Documentation [on hexdocs.pm](https://hexdocs.pm/hanabi/readme.html).
  * [RFC1459](https://tools.ietf.org/html/rfc1459) : Internet Relay Chat
  Protocol
    * RFC2810
    * RFC2811
    * RFC2812
    * RFC2813
    * [modern.ircdocs.horse](https://modern.ircdocs.horse/)
  * Parts of the IRC-related code were inspired by
[radar/elixir-irc](https://github.com/radar/elixir-irc).

## Usage & configuration

You must add (and fill) the following to your `config/config.exs` file :

```
config :hanabi, port: 6667,
                hostname: "my.awesome.hostname",
                motd: "/path/to/motd.txt"
```

You only have to add `hanabi` in the dependency section of your `mix.exs` file.
You can start it with `Hanabi.start/0` or `Hanabi.start/2`.
