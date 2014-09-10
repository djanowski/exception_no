require "cutest"
require "mini-smtp-server"

require_relative "../lib/exception_no"

class SMTPServer < MiniSmtpServer
  attr :outbox

  def initialize(*args)
    @outbox = QueueWithTimeout.new
    super(*args)
  end

  def new_message_event(message)
    @outbox << message
    true
  end
end

# Source: http://spin.atomicobject.com/2014/07/07/ruby-queue-pop-timeout
class QueueWithTimeout
  def initialize
    @mutex = Mutex.new
    @queue = []
    @recieved = ConditionVariable.new
  end

  def <<(x)
    @mutex.synchronize do
      @queue << x
      @recieved.signal
    end
  end

  def size
    @queue.size
  end

  def clear
    @mutex.synchronize do
      @queue.clear
    end
  end

  def pop(timeout = 2)
    @mutex.synchronize do
      if @queue.empty?
        @recieved.wait(@mutex, timeout) if timeout != 0
        raise ThreadError, "queue empty" if @queue.empty?
      end
      @queue.pop
    end
  end
end

def parse_email(raw)
  headers = {}
  body = []
  reading_body = false

  raw.each_line do |line|
    if !reading_body && line == "\r\n"
      reading_body = true
      next
    end

    if reading_body
      body << line
    else
      key, value = line.split(": ", 2)
      headers[key] = value && value.chomp
    end
  end

  body.pop

  return headers, body.join("").chomp
end

def capture_stderr
  old, $stderr = $stderr, StringIO.new

  begin
    yield
  ensure
    $stderr = old
  end
end

prepare do
  $smtp.outbox.clear
end

$smtp = SMTPServer.new(2525, "127.0.0.1")
$smtp.start

until SMTPServer.in_service?(2525)
end

at_exit do
  if $smtp
    $smtp.stop
    $smtp.join
  end
end
