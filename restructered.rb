require 'socket'
require 'pry'

START_TIME = Time.now

class Server
  attr_reader :users,:channels

  def initialize port
    @socket = TCPServer.new port
    @message_handlers = {}
    @channels = {}
    @hostname = 'localhost'
    @users = []
    setup_messages
    run
  end

  def run
    loop do
      User.new(@socket.accept,self)
    end
  end

  def make_channel name
    @channels[name] = Channel.new name
  end

  def def_message name, &block
    @message_handlers[name] = block
  end

  def accept_connection target
    strs = [":localhost 001 %s :Welcome %s! %s@%s" % [target.nick,target.nick,target.username,target.host],
	    ":localhost 002 %s :Your host is %s" % [target.nick, @hostname],
	    ":localhost 003 %s :Server started at %s" % [target.nick, START_TIME],
	    ":localhost 004 %s :idklol" % [target.nick]]
    strs.each{|s| target.send_message s}
    @users << target
  end

  def setup_messages

    @message_handlers.default_proc do |hash,key|
      puts ("%s %s" % [hash,key].map(&:to_s))
    end

    def_message "NICK" do |args,target,text|
      target.nick = args[0]
      target.send_message ":localhost NICK #{target.nick}"

    end

    def_message "JOIN" do |args,target,text|
      unless @channels[ args[0] ]
	make_channel args[0]
      end

      @channels[ args[0] ].add_user target
    end

    def_message "USER" do |args,target,text|
      target.username = args[0]
      target.host = args[2]
      accept_connection target
    end

    def_message "PING" do |args,target,text|
      target.send_message ":#{@hostname} PONG localhost"
    end

    def_message "MODE" do |args,target,text|
      puts ("IMPLEMENT ME: MODE")
    end

    def_message "QUIT" do |args,target,text|
      target.disconnect
    end

    def_message "PRIVMSG" do |args,target,text|
      if args[0][0] == '#'
	# Send to channel
	@channels[args[0]].broadcast text, target
      else
	# Send to user
      end
    end
  end

  def process_message message, sender

    # May the dark lord have mercy upon he who casts the spell known as regex
    mystical_incantation = /^(?<hostname>:[^ ]+ )?(?<args>[^:]+)(?<text>$|(:[^$]+)$)/
    match = message.match mystical_incantation

    parts = match["args"].split
    
    unless @message_handlers[parts[0]]
      puts ("IMPLEMENT %s" % parts[0])
    else
      @message_handlers[parts[0]].call parts.drop(1), sender, match["text"][1..-1]
    end
  end

  class User
    attr_reader :socket,:thread, :kill
    attr_accessor :nick, :host, :username

    def initialize socket,server
      @socket = socket
      @kill = false
      @server = server

      @username = ""
      get_input_threaded

    end

    def get_input_
      @socket.readlines
    end

    def get_input_threaded
      @thread = Thread.new do
	while not @kill do
	  line = socket.gets
	    @server.process_message line, self
	  end
	unless @kill
	  socket.close
	end
	@kill = true
      end
    end

    def disconnect
      @kill = true
      @socket.close
    end

    def send_message msg
      puts "Sending: #{msg}"
      @socket.write(msg+"\r\n")
    end

  end

  class Channel
    attr_accessor :users,:name

    def initialize name
      @name = name
      @users = []
    end

    def add_user user
      @users << user
    end

    def broadcast msg, sender
      puts "#{sender.nick}@#{@name} said: #{msg}"

      @users.each do |u|
	unless u == sender
	  u.send_message ":#{sender.nick} PRIVMSG #{@name} :#{msg}"
	end
      end
    end
  end


  def self.process_message message
    # Takes a string and returns it's fields in an easily usable hash
  end

  def self.validate_message message
    #TODO write a regex to validate a string is a valid irc string 
    /^\:[a-zA-Z]+ [0-9]{3} \:[.]*$/
  end
end

Thread.abort_on_exception = true
myserver = Server.new 2000
