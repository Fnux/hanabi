defmodule HanabiTest.User do
  alias Hanabi.{User, IRC.Message}
  use ExUnit.Case
  use Hanabi.IRC.Numeric

  setup do
    User.flush_registry
    {key, user} = HanabiTest.build_test_user("default")

    # Bypass validations of `add/1` and `add/7`
    User.set key, user

    # Returned context
    [user: user]
  end

  test "Change the nick of an user", context do
    user = context[:user]

    assert User.change_nick(:unknown, "unused") == {:err, :no_such_user}
    assert User.change_nick(user.key, "#!à$äö") == {:err, @err_erroneusnickname}
    assert User.change_nick(user.key, "default") == {:err, @err_nicknameinuse}
    assert User.change_nick(user, "unused") == {:ok, struct(user, nick: "unused")}
  end

  test "Add an user", context do
    user = context[:user]
    incomplete_user = %User{}
    valid_username_user = struct(user, username: "valid")
    invalid_pid_user = struct(valid_username_user, pid: :atom)
    invalid_nick_user = struct(valid_username_user, nick: "#!à$äö")
    invalid_key_user = struct(valid_username_user, nick: "valid")
    valid_user = struct(invalid_key_user, key: :valid)

    assert User.add(incomplete_user) == {:err, @err_needmoreparams}
    assert User.add(user) == {:err, @err_alreadyregistered}
    assert User.add(invalid_nick_user) == {:err, @err_erroneusnickname}
    assert User.add(invalid_pid_user) == {:err, :invalid_pid}
    assert User.add(invalid_key_user) == {:err, :key_in_use}
    assert User.add(valid_user) == {:ok, valid_user.key}
  end

  # Should also check that the user was removed from every chan
  test "Remove an user", context do
    user = context[:user]

    User.remove(user)

    assert User.get(user.key) == nil
  end

  test "Send a message to an user", context do
    user = context[:user]

    msg = %Message{command: "TEST"}

    # Sending
    assert user.type == :virtual
    assert User.send(:unknown, msg) == :err
    assert User.send(user.key, msg) == :ok

    # Receiving
    received = receive do
      new_msg -> new_msg
    after
      5000 -> :timeout
    end
    assert received ==  msg

    # Check for 'void' users @TODO
  end

  test "Broadcast a message for an user"
end
