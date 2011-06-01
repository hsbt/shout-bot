=begin
ShoutBot
  Ridiculously simple library to quickly say something on IRC
  <http://github.com/sr/shout-bot>

EXAMPLE

  ShoutBot.shout('irc://shoutbot:password@irc.freenode.net:6667/#github') do |channel|
    channel.say "check me out! http://github.com/sr/shout-bot"
  end

LICENSE

             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                     Version 2, December 2004

  Copyright (C) 2008, 2009 Simon Rozet <http://purl.org/net/sr/>
  Copyright (C) 2008, 2009 Harry Vangberg <http://trueaffection.net>

  Everyone is permitted to copy and distribute verbatim or modified
  copies of this license document, and changing it is allowed as long
  as the name is changed.

             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
    TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

   0. You just DO WHAT THE FUCK YOU WANT TO.
=end

require "addressable/uri"
require "socket"
require "openssl"

class ShoutBot
  def self.shout(uri, password = nil, ssl = false, &block)
    raise ArgumentError unless block_given?

    uri = Addressable::URI.parse(uri)
    irc = new(uri.host, uri.port, uri.user, uri.password, ssl) do |irc|
      if channel = uri.fragment
        irc.join(channel, password, &block)
      else
        irc.channel = uri.path[1..-1]
        yield irc
      end
    end
  end

  attr_accessor :channel

  def sendln(cmd)
    @socket.write("#{cmd}\r\n")
    STDOUT.flush
  end

  def initialize(server, port, nick, password, ssl)
    raise ArgumentError unless block_given?

    tcp_socket = TCPSocket.new(server, port || 6667)
    if ssl
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
      @socket.sync = true
      @socket.connect
    else
      @socket = tcp_socket
    end
    sendln "PASS #{password}" if password
    sendln "NICK #{nick}"
    sendln "USER #{nick} 0 * :#{nick}"
    sleep 1
    yield self
    sendln "QUIT :quit"
    @socket.gets until @socket.eof?
  end

  def join(channel, password)
    raise ArgumentError unless block_given?

    @channel = "##{channel}"
    password = password && " #{password}" || ""
    sendln "JOIN #{@channel}#{password}"
    yield self
    sendln "PART #{@channel}"
  end

  def say(message)
    return unless @channel
    sendln "PRIVMSG #{@channel} :#{message}"
  end
end
