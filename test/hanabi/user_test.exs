defmodule HanabiTest.User do
  alias Hanabi.{User, Channel, IRC.Message}
  use ExUnit.Case
  use Hanabi.IRC.Numeric

  @alpha HanabiTest.Helper.build_test_user("alpha")
  @beta HanabiTest.Helper.build_test_user("beta")
  @gamma HanabiTest.Helper.build_test_user("gamma")

  @greek HanabiTest.Helper.build_test_channel("#greek")
  @latin HanabiTest.Helper.build_test_channel("#latin")

  setup do
    # Remove existing data
    User.flush_registry
    Channel.flush_registry

    # Add test users and channels
    for user <- [@alpha, @beta, @gamma] do
      User.set user.key, user
    end
    for channel <- [@greek, @latin] do
      Channel.set channel.name, channel
    end

    Channel.add_user(@beta, @greek)
    Channel.add_user(@beta, @latin)
    Channel.add_user(@gamma, @latin)

    :ok
  end

  test "Change the nick of an user" do
    assert User.change_nick(:unknown, "unused") == {:err, :no_such_user}
    assert User.change_nick(@alpha.key, "#!à$äö") == {:err, @err_erroneusnickname}
    assert User.change_nick(@alpha.key, "beta") == {:err, @err_nicknameinuse}
    assert User.change_nick(@alpha, "unused") == {:ok, struct(@alpha, nick: "unused")}
  end

  test "Add an user" do
    incomplete_user = %User{}
    valid_username_user = struct(@alpha, username: "valid")
    invalid_pid_user = struct(valid_username_user, pid: :atom)
    invalid_nick_user = struct(valid_username_user, nick: "#!à$äö")
    invalid_key_user = struct(valid_username_user, nick: "valid")
    valid_user = struct(invalid_key_user, key: :valid)

    assert User.add(incomplete_user) == {:err, @err_needmoreparams}
    assert User.add(@alpha) == {:err, @err_alreadyregistered}
    assert User.add(invalid_nick_user) == {:err, @err_erroneusnickname}
    assert User.add(invalid_pid_user) == {:err, :invalid_pid}
    assert User.add(invalid_key_user) == {:err, :key_in_use}
    assert User.add(valid_user) == {:ok, valid_user.key}
  end

  test "Remove an user" do
    User.remove(@alpha)

    assert User.get(@alpha.key) == nil

    # Check if the user was properly removed from channels @TODO
  end

  test "Send a message to an user" do
    alpha = User.update(@alpha, pid: self())
    msg = %Message{command: "TEST"}

    # Sending
    assert alpha.type == :virtual
    assert alpha.pid == self()
    assert User.send(:unknown, msg) == :err
    assert User.send(alpha.key, msg) == :ok

    # Receiving
    received = receive do
      new_msg -> new_msg
    after
      5000 -> :timeout
    end
    assert received ==  msg

    # Check for 'void' users @TODO
  end

  @tag :todo
  test "Broadcast a message for an user"
end
