defmodule HanabiTest.User.Registry do
  alias Hanabi.User
  use ExUnit.Case

  @alpha HanabiTest.build_test_user("alpha")
  @beta HanabiTest.build_test_user("beta")
  @gamma HanabiTest.build_test_user("gamma")

  setup do
    # Remove all exisring data
    User.flush_registry

    # Add some test users
    for user <- [@alpha, @beta, @gamma] do
      User.set user.key, user
    end

    # No context
    :ok
  end

  # get/1
  test "User get registry" do
    assert User.get(:alpha) == @alpha
    assert User.get(:unknown) == nil
  end

  # get_all/0
  test "User registry get_all" do
    output = User.get_all

    assert [{@gamma.key, @gamma}] in output
    assert [{@alpha.key, @alpha}] in output
    assert [{@beta.key, @beta}] in output
  end

  # update/2
  test "User registry update" do
    changeset = %{nick: "newnick"}

    assert User.update(@alpha, changeset) == struct(@alpha, changeset)
    assert User.get(@alpha.key) == struct(@alpha, changeset)
    assert User.update(:unknown, changeset) == nil
  end

  # set/2
  test "User registry set" do
    delta = HanabiTest.build_test_user("delta")

    assert User.set(@alpha.key, delta) == false # Cannot override existing data
    assert User.get(@alpha.key) == @alpha
    assert User.set(delta.key, delta) == true
    assert User.get(delta.key) == delta
  end

  # destroy/1
  test "User registry destroy" do
    assert User.destroy(@alpha.key) == true
    assert User.get(@alpha.key) == nil
    assert User.destroy(@alpha.key) == false
  end

  # get_by/2
  test "User registry get_by" do
    assert User.get_by(:nick, @alpha.nick) == @alpha
    assert User.get_by(:nick, "unknown") == nil
    assert User.get_by(:unknown, @alpha.nick) == nil
  end

  # is_in_use?/2
  test "User registry is_in_use?" do
    assert User.is_in_use?(:nick, @alpha.nick) == true
    assert User.is_in_use?(:nick, "new_nick") == false
  end
end
