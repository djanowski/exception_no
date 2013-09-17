require "cutest"
require "mini-smtp-server"

require_relative "../lib/exception_no"

class SMTPServer < MiniSmtpServer
  def outbox
    @outbox ||= []
  end

  def new_message_event(message)
    outbox << message
    true
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
