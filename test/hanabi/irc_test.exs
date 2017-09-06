defmodule HanabiTest.IRC do
  alias Hanabi.{IRC, IRC.Message}
  use ExUnit.Case
  use Hanabi.IRC.Numeric

  test "IRC command parser" do
    privmsg = ":Angel PRIVMSG Wiz :Hello are you receiving this message ?"
    topic = "TOPIC #test"
    user = "USER guest tolmoon tolsun :Ronnie Reagan"

    assert IRC.parse(privmsg) == %Message{
      command: "PRIVMSG",
      middle: "Wiz",
      prefix: "Angel",
      trailing: "Hello are you receiving this message ?"
    }

    assert IRC.parse(topic) == %Message{
      command: "TOPIC",
      middle: "#test"
    }

    assert IRC.parse(user) == %Message{
      command: "USER",
      middle: "guest tolmoon tolsun",
      trailing: "Ronnie Reagan"
    }
  end

  test "IRC command builder" do
    privmsg = %Message{
      command: "PRIVMSG",
      middle: "Wiz",
      prefix: "Angel",
      trailing: "Hello are you receiving this message ?"
    }
    topic = %Message{
      command: "TOPIC",
      middle: "#test"
    }
    user = %Message{
      command: "USER",
      middle: "guest tolmoon tolsun",
      trailing: "Ronnie Reagan"
    }

    assert IRC.build(privmsg) == ":Angel PRIVMSG Wiz :Hello are you receiving this message ?"
    assert IRC.build(topic) == "TOPIC #test"
    assert IRC.build(user) == "USER guest tolmoon tolsun :Ronnie Reagan"
  end

  test "IRC nickname validation" do
    valid = "lambda"
    invalid_1 = "#lambda"
    invalid_2 = "la!+mbda"

    assert IRC.validate(:nick, invalid_1) == {:err, @err_erroneusnickname}
    assert IRC.validate(:nick, invalid_2) == {:err, @err_erroneusnickname}
    assert IRC.validate(:nick, valid) == {:ok, valid}
  end

  test "IRC channel name validation" do
    valid = "#hanabi"
    invalid_1 = "hanabi"
    invalid_2 = "# ewer"

    assert not IRC.validate(:channel, invalid_1)
    assert not IRC.validate(:channel, invalid_2)
    assert IRC.validate(:channel, valid)
  end
end
