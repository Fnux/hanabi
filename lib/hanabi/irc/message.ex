defmodule Hanabi.IRC.Message do
  alias Hanabi.IRC.Message
  @moduledoc """
  This module defines the message structure widely used in this library. More
  informations about the structure of an IRC message can be found in
  [the section 2.3.1 of RFC1459](https://tools.ietf.org/html/rfc1459#section-2.3.1).

  ```
  %Hanabi.IRC.Message{
    command: "",
    middle: nil,
    prefix: nil,
    trailing: nil
  }
  """

  # See https://tools.ietf.org/html/rfc1459#section-2.3.1
  defstruct prefix: nil,
    command: "",
    middle: nil,
    trailing: nil

  @doc """
  Convenience function to build a message structure.

  ## Example

  ```
  iex> msg = Hanabi.IRC.Message.build("Angel", "PRIVMSG", "Wiz", "Hello are you receiving this message ?")
  %Hanabi.IRC.Message{command: "PRIVMSG", middle: "Wiz", prefix: "Angel",
    trailing: "Hello are you receiving this message ?"}
  iex> Hanabi.IRC.build msg
  ":Angel PRIVMSG Wiz :Hello are you receiving this message ?"
  ```
  """
  def build(prefix, command, middle, trailing) do
    %Message{
      prefix: prefix,
      command: command,
      middle: middle,
      trailing: trailing
    }
  end
end
