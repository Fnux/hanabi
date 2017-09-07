defmodule HanabiTest do
  alias Hanabi.{User, Channel}

  def build_test_users(nicks, results \\ [])
  def build_test_users([], results), do: results
  def build_test_users([nick|tail], results) do
    pair = build_test_user(nick)

    build_test_users(tail, results ++ [pair])
  end

  def build_test_user(nick) when is_binary(nick) do
    key = String.to_atom(nick)

    %User{
      key: key,
      nick: nick,
      username: nick,
      realname: nick,
      hostname: "localhost",
      type: :virtual,
      pid: self()
    }
  end

  def build_test_channel(name) when is_binary(name) do
    %Channel{name: name, topic: "Default Topic"}
  end
end
