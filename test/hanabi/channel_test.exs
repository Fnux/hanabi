defmodule HanabiTest.Channel do
  alias Hanabi.{User, Channel, IRC.Message}
  use ExUnit.Case
  use Hanabi.IRC.Numeric

  setup do
    User.flush_registry
    Channel.flush_registry

    # add users
    for nick <- ["lambda", "beta", "gamma"] do
      {key, user} = HanabiTest.build_test_user(nick)
      User.set key, user
    end

    # Add channels
    {key, channel} = HanabiTest.build_test_channel("#greek")
    Channel.set key, channel

    #
    Channel.add_user(:beta, "#greek")
    Channel.add_user(:gamma, "#greek")

    :ok
  end

  test "Add an user to a channel" do

    assert Channel.get("#hanabi") == nil
    {status, updated_channel} = Channel.add_user(:lambda, "#hanabi")
    assert status == :ok
    assert Channel.get("#hanabi") == updated_channel
    assert :lambda in updated_channel.users

    assert Channel.add_user("unknown", "#hanabi") == {:err, :no_such_user}
    assert Channel.get("#hanabi").users == [:lambda]

    # Check JOIN messages @TODO
  end

  test "Remove an user from a channel" do
    assert Channel.remove_user(:beta, "#unknown") == {:err, @err_nosuchchannel}
    assert Channel.remove_user(:gamma, "#hanabi") == {:err, @err_notonchannel}
    assert Channel.remove_user(:unknown, "#greek") == {:err, :no_such_user}

    assert :beta in Channel.get("#greek").users
    {status, updated_channel} = Channel.remove_user(:beta, "#greek")
    assert status == :ok
    assert :beta not in updated_channel.users

    # Check PART messages @TODO
  end

  test "Set the topic of a channel" do
    assert Channel.set_topic("#greek", "New topic!") == :ok
    assert Channel.get("#greek").topic == "New topic!"

    assert Channel.set_topic("#unknown", "New topic!") == :err
    assert Channel.set_topic("#greek", nil) == :err

    # Check TOPIC IRC messages @TODO
  end

  test "Send a message to a channel" do
    msg = %Message{command: "TEST"}

    Channel.broadcast("#greek", msg)

    # Check received messages @TODO
  end

  test "Get the nicknames of a channel's users" do
    list = Channel.get("#greek").users |> Channel.get_names

    assert list == "beta gamma"
  end
end
