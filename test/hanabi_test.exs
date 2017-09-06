defmodule HanabiTest do
  alias Hanabi.User

  def build_test_users(nicks, results \\ [])
  def build_test_users([], results), do: results
  def build_test_users([nick|tail], results) do
    pair = build_test_user(nick)

    build_test_users(tail, results ++ [pair])
  end

  def build_test_user(nick) when is_binary(nick) do
    key = String.to_atom(nick)
    user = %User{
      key: key,
      nick: nick,
      username: nick,
      realname: nick,
      hostname: "localhost",
      type: :virtual,
      pid: self()
    }

    {key, user}
  end
end
