defmodule HanabiTest.User.Registry do
  alias Hanabi.User
  use ExUnit.Case

  setup_all do
    Hanabi.start()

    :ok
  end

  setup do
    Hanabi.Registry.flush(:hanabi_users)
    [{_, first_user}, {_, second_user}] =
      HanabiTest.build_test_users(["first", "second"])

    #
    Hanabi.User.set first_user.key, first_user
    Hanabi.User.set second_user.key, second_user

    # Returned context
    [users: %{first: first_user, second: second_user}]
  end


  # old

  # get/1
  test "User get registry", context do
    user = context[:users].first

    assert User.get(user.key) == user
    assert User.get(:unknown) == nil
  end

  # get_all/0
  test "User registry get_all", context do
    users = context[:users]
    %{first: first, second: second} = users

    assert User.get_all == [[{first.key, first}], [{second.key, second}]]
  end

  # update/2
  test "User registry update", context do
    user = context[:users].first
    changeset = %{nick: "updated"}

    assert User.update(user, changeset) == struct(user, changeset)
    assert User.get(user.key) == struct(user, changeset)
    assert User.update(:unknown, user) == nil
  end

  # set/2
  test "User registry set", context do
    first_user = context[:users].first
    {_, third_user} = HanabiTest.build_test_user("third")

    assert User.set(first_user.key, third_user) == false # cannot override
    assert User.set(third_user.key, third_user) == true
    assert User.get(third_user.key) == third_user
  end

  # destroy/1
  test "User registry destroy", context do
    user = context[:users].first

    assert User.destroy(user.key) == true
    assert User.get(user.key) == nil
    assert User.destroy(user.key) == true # false?
  end

  # get_by/2
  test "User registry get_by", context do
    user = context[:users].first

    assert User.get_by(:nick, user.nick) == user
    assert User.get_by(:nick, "unknown") == nil
    assert User.get_by(:unknown, user.key) == nil
  end

  # is_in_use?/2
  test "User registry is_in_use?", context do
    user = context[:users].first

    assert User.is_in_use?(:nick, user.nick) == true
    assert User.is_in_use?(:nick, "unused") == false
  end
end
