defmodule HanabiTest.Channel.Registry do
  alias Hanabi.Channel
  use ExUnit.Case

  @greek HanabiTest.Helper.build_test_channel("#greek")
  @latin HanabiTest.Helper.build_test_channel("#latin")

  setup do
    # Remove all existing data
    Channel.flush_registry

    # Add some test channels
    for channel <- [@greek, @latin] do
      Channel.set channel.name, channel
    end

    # Returned context
    :ok
  end

  # get/1
  test "Channel get registry"do
    assert Channel.get(@greek.name) == @greek
    assert Channel.get(:unknown) == nil
  end

  # get_all/0
  test "Channel registry get_all" do
    output = Channel.get_all

    assert [{@greek.name, @greek}] in output
    assert [{@latin.name, @latin}] in output
  end

  # update/2
  test "Channel registry update" do
    changeset = %{topic: "updated"}

    assert Channel.update(@greek, changeset) == struct(@greek, changeset)
    assert Channel.get(@greek.name) == struct(@greek, changeset)
    assert Channel.update(:unknown, changeset) == nil
  end

  # set/2
  test "Channel registry set" do
    hebrew = HanabiTest.Helper.build_test_channel("#hebrew")

    assert Channel.set(@greek.name, hebrew) == false # cannot override
    assert Channel.get(@greek.name) == @greek
    assert Channel.set(hebrew.name, hebrew) == true
    assert Channel.get(hebrew.name) == hebrew
  end

  # destroy/1
  test "Channel registry destroy" do
    assert Channel.destroy(@greek.name) == true
    assert Channel.get(@greek.name) == nil
    assert Channel.destroy(@greek.name) == false
  end
end
