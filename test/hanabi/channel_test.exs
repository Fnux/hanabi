defmodule HanabiTest.Channel do
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

  test "Add an user to a channel" do
    # Add an user to a non-existing channel
    assert Channel.get("#hanabi") == nil
    {status, updated_channel} = Channel.add_user(@alpha.key, "#hanabi")
    assert status == :ok
    assert Channel.get("#hanabi") == updated_channel
    assert updated_channel.users == [@alpha.key]

    # Add a non-existent user
    assert Channel.add_user("unknown", "#hanabi") == {:err, :no_such_user}
    assert Channel.get("#hanabi").users == [@alpha.key]

    assert @beta.key in Channel.get(@latin.name).users
    assert @gamma.key in Channel.get(@latin.name).users

    # Check JOIN messages @TODO
  end

  test "Remove an user from a channel" do
    assert Channel.remove_user(@alpha, "#unknown") == {:err, @err_nosuchchannel}
    assert Channel.remove_user(@alpha, @greek) == {:err, @err_notonchannel}
    assert Channel.remove_user(@alpha.key, @greek.name) == {:err, @err_notonchannel}
    assert Channel.remove_user(:unknown, @greek) == {:err, :no_such_user}

    assert @beta.key in Channel.get(@greek.name).users
    {status, updated_channel} = Channel.remove_user(@beta.key, @greek.name)
    assert status == :ok
    assert @beta.key not in updated_channel.users

    # Check PART messages @TODO
  end

  test "Set the topic of a channel" do
    assert Channel.get(@greek.name).topic != "New topic!"
    assert Channel.set_topic(@greek, "New topic!") == :ok
    assert Channel.get(@greek.name).topic == "New topic!"
    assert Channel.set_topic(@greek.name, "Wrong topic!") == :ok
    assert Channel.get(@greek.name).topic != "New topic!"

    assert Channel.set_topic("#unknown", "New topic!") == :err
    assert Channel.set_topic(@greek, nil) == :err

    # Check TOPIC IRC messages @TODO
  end

  test "Send a message to a channel" do
    msg = %Message{command: "TEST"}

    Channel.broadcast(@greek, msg)

    # Check received messages @TODO
  end

  test "Get the nicknames of a channel's users" do
    list = Channel.get(@latin.name).users |> Channel.get_names

    assert list == "beta gamma"
  end
end
