defmodule Hanabi.IRC.Numeric do

  @moduledoc """
  @TODO
  """

  ####################
  # IRC Numeric Codes
  ####################

  defmacro __using__(_) do
    quote do
      @rpl_topic "332"
      @rpl_namreply "353"
      @rpl_endofnames "366"
      @rpl_motdstart "375"
      @rpl_motd "372"
      @rpl_endofmotd "376"

      @err_nosuchnick "401"
      @err_nosuchchannel "403"
      @err_nomotd "422"
      @err_erroneusnickname "432"
      @err_nicknameinuse "433"
      @err_notonchannel "442"
      @err_needmoreparams "461"
      @err_alreadyregistered "462"
    end
  end
end
