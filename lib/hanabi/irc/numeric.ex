defmodule Hanabi.IRC.Numeric do

  @moduledoc """
  This module maps numeric replies (as defined in
  [RFC1459, section 6](https://tools.ietf.org/html/rfc1459#section-6)) to
  more convenient constants. (e.g. : `@rpl_topic "332"`). Please take
  a look to the
  [module's source code](https://github.com/Fnux/hanabi/blob/master/lib/hanabi/irc/numeric.ex)
  for a detailed list.

  **Note :** the numeric values are stored as string (they're often used in
  the `:command` field of a `Hanabi.IRC.Message` struct).

  How to use them ? Just add `use Hanabi.IRC.Numeric` at the top of your module.
  """

  ####################
  # IRC Numeric Codes
  ####################

  defmacro __using__(_) do
    quote do
      @rpl_whoisuser "311"
      @rpl_endofwhois "318"
      @rpl_liststart "321"
      @rpl_list "322"
      @rpl_listend "323"
      @rpl_topic "332"
      @rpl_namreply "353"
      @rpl_endofnames "366"
      @rpl_motdstart "375"
      @rpl_motd "372"
      @rpl_endofmotd "376"

      @err_nosuchnick "401"
      @err_nosuchchannel "403"
      @err_nomotd "422"
      @err_nonicknamegiven "431"
      @err_erroneusnickname "432"
      @err_nicknameinuse "433"
      @err_notonchannel "442"
      @err_needmoreparams "461"
      @err_alreadyregistered "462"
    end
  end
end
