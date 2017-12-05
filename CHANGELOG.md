# Changelog for Hanabi (hanabi on hex.pm)

## v.?.? (????-??-??)

* Add support for user modes (via the `Hanabi.User` module and the MODE command)
* Add support for the following user modes : "r"
* Add RPL_WELCOME, RPL_YOURHOST, RPL_CREATED and RPL_MYINFO to the "greeting"
  sequence (improving compatibility with 'recent' IRC clients)

## v0.1.1 (2017-11-28)

* Use ETS to lookup users using non-key elements (nick, username, ...)
* Add the `data` field to the Hanabi.User and Hanabi.Channel structs, allowing
  the user to store custom values
* Channel : only relay messages to the users having their `type` in the
  `relay_to` field
* Add the possibility to set a server-wide password (PASS) in `config.exs`
* Add handling of the list (LIST) message
* Add handling of the whois (WHOIS) query

## v0.1.0 (2017-09-11)

* Add basic tests
* Add a few usage examples to the README
* Major refactoring/restructuration of the library
  * New usage/API
  * New documentation

## v0.0.4 and previous (201?-??-??)

* Old & undocumented stuff
