defmodule HanabiTest.Channel.Registry do
  alias Hanabi.Channel
  use ExUnit.Case

  setup do
    Channel.flush_registry

    {key, channel} = HanabiTest.build_test_channel("#hanabi")

    #
    Hanabi.Channel.set key, channel

    # Returned context
    [channel: channel]
  end

  # get/1
  test "Channel get registry", context do
    channel = context[:channel]

    assert Channel.get(channel.name) == channel
    assert Channel.get(:unknown) == nil
  end

  # get_all/0
  test "Channel registry get_all", context do
    channel = context[:channel]

    assert Channel.get_all == [[{channel.name, channel}]]
  end

  # update/2
  test "Channel registry update", context do
    channel = context[:channel]
    changeset = %{topic: "updated"}

    assert Channel.update(channel, changeset) == struct(channel, changeset)
    assert Channel.get(channel.name) == struct(channel, changeset)
    assert Channel.update(:unknown, channel) == nil
  end

  # set/2
  test "Channel registry set", context do
    channel = context[:channel]
    {_, second_channel} = HanabiTest.build_test_channel("second")

    assert Channel.set(channel.name, second_channel) == false # cannot override
    assert Channel.set(second_channel.name, second_channel) == true
    assert Channel.get(second_channel.name) == second_channel
  end

  # destroy/1
  test "Channel registry destroy", context do
    channel = context[:channel]

    assert Channel.destroy(channel.name) == true
    assert Channel.get(channel.name) == nil
    assert Channel.destroy(channel.name) == true # false?
  end
end
