defmodule Hanabi.IRC do
  alias Hanabi.User
  alias Hanabi.IRC.Message
  require Logger
  use Hanabi.IRC.Numeric

  @moduledoc """
  IRC-related methods used for common tasks such as parsing/building/sending/validating.
  """

  @doc """
  Parse an IRC message (= string) into a `Hanabi.IRC.Message` struct.

  ## Example

  ```
  iex> Hanabi.IRC.parse ":Angel PRIVMSG Wiz :Hello are you receiving this message ?"
  %Hanabi.IRC.Message{command: "PRIVMSG", middle: "Wiz", prefix: "Angel",
    trailing: "Hello are you receiving this message ?"}
  iex> Hanabi.IRC.parse ":WiZ NICK Kilroy"
  %Hanabi.IRC.Message{command: "NICK", middle: "Kilroy", prefix: "WiZ",
    trailing: nil}
  ```
  """
  def parse(data) do
    line = String.trim(data)
    regex = ~r/^(?:[:](\S+) )?(\S+)\s?(.*)$/ui

    if String.match?(line, regex) do
      [_, prefix, command, params] = Regex.run(regex, line)
      {middle, trailing} = parse(:params, params)

      %Message{prefix: prefix, command: command, middle: middle, trailing: trailing}
    else
      %Message{}
    end
  end

  def parse(_, params_string, middle_params \\ nil)

  @doc false
  def parse(:params, "", middle_params), do: {middle_params, nil}
  def parse(:params, params_string, middle_params) do
    [head|tail] = String.split params_string, " ", parts: 2

    if String.starts_with?(head, ":") do
      # 'trailing' parameter
      trailing = unless tail == []do
        String.trim_leading(head, ":") <> " " <> List.to_string(tail)
      else
        String.trim_leading(head, ":")
      end
      {middle_params, trailing}
    else
      # 'middle' parameter
      middle = if middle_params, do: middle_params <> " " <> head, else: head
      parse(:params, List.to_string(tail), middle)
    end
  end

  @doc """
  Resolves and returns an hostname given the port identifier of a TCP socket.

  If unable to determine the host, this methods returns the IP address.
  Used to populate the `:hostname` field of the `Hanabi.User` struct.

  ## Example

  ```
  iex>  {:ok, port} = :gen_tcp.connect String.to_charlist("fnux.ch"), 80, [:binary]
  {:ok, #Port<0.6707>}
  iex> Hanabi.IRC.resolve_hostname port
  'kyrkja.fnux.ch'
  ```
  """
  def resolve_hostname(client) do
    {:ok, {ip, _port}} = :inet.peername(client)
    case :inet.gethostbyaddr(ip) do
      { :ok, { :hostent, hostname, _, _, _, _}} ->
        hostname
      { :error, _error } ->
        Logger.debug "Could not resolve hostname for #{ip}. Using IP instead."
        Enum.join(Tuple.to_list(ip), ".")
    end
  end

  @doc """
  Build an IRC message given the message structure defined in
  `Hanabi.IRC.Message`.

  ## Example

  ```
  iex> msg = %Hanabi.IRC.Message{command: "PRIVMSG", middle: "Wiz", prefix: "Angel",
    trailing: "Hello are you receiving this message ?"}
  iex> Hanabi.IRC.build msg
  ":Angel PRIVMSG Wiz :Hello are you receiving this message ?"
  ```
  """
  def build(%Message{}=msg) do
    prefix = if msg.prefix, do: ":#{msg.prefix} ", else: ""
    command = msg.command
    {middle, trailing } = case {msg.middle, msg.trailing} do
      {nil, nil} -> {"", ""}
      {mid, nil} -> {" #{mid}", ""}
      {nil, trail} -> {"", " :#{trail}"}
      {mid, trail} -> {" #{mid}", " :#{trail}"}
    end

    prefix <> command <> middle <> trailing
  end

  @doc """
  Send a message over the `port` TCP socket.

  * If `msg` is a `Hanabi.IRC.Message` structure, it will be transformed into a
  properly formatted string using `build/1`
  * If `msg` already is string, it will directly be transmitted

  This method takes care to append `<crlf>` at the end of the transmitted string.
  """
  def send(port, %Message{}=msg) do
    :gen_tcp.send port, build(msg) <> "\r\n"
  end

  def send(port, msg) do
    :gen_tcp.send port, msg <> "\r\n"
  end

  ## IRC helpers

  @doc """
  Validates various IRC-related strutures/formats.

  ## Nickname validation

  `validate(:nick, nick)`

  Return values :
    * `{:ok, nick}` if the nickname is valid and unused
    * `{:err, @err_erroneusnickname}` if the nickname is invalid
    * `{:err, @err_nicknameinuse}` if the nickname is valid but already in use

  `@err_erroneusnickname` and `@err_nicknameinuse` are defined in `Hanabi.IRC.Numeric`.
  ```
  iex> Hanabi.IRC.validate :nick, "fnux"
  {:ok. "fnux"}
  iex> Hanabi.IRC.validate :nick, "#fnux"
  {:err, "432"}
  ```

  ## Channel name validation

  `validate(:channel, name)`

  ```
  iex> Hanabi.IRC.validate :channel, "#hanabi"
  true
  iex> Hanabi.IRC.validate :channel, "hanabi"
  false
  ```

  ## User validation

  `validate(:user, user)`

  Validates a 'registerable' user (= all the required informations are present).

  * `user` must be a `Hanabi.User` struct
  * the presence of the following fields is checked : `:key, :nick, :username,
  :realname, :hostname`
  """
  def validate(:nick, nick) do
    regex = ~r/\A[a-z_\-\[\]\\^{}|`][a-z0-9_\-\[\]\\^{}|`]{2,15}\z/ui

    cond do
      !String.match?(nick, regex) -> {:err, @err_erroneusnickname}
      User.is_in_use?(:nick, nick) -> {:err, @err_nicknameinuse}
      true -> {:ok, nick}
    end
  end

  def validate(:channel, name) do
    regex = ~r/#\w+/ui
    String.match?(name, regex)
  end

  def validate(:user, %User{}=user) do
    user.key && user.nick && user.username && user.realname && user.hostname
  end
end
