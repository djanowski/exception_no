require "net/smtp"
require "erb"

class ExceptionNo
  VERSION = "0.0.1"

  attr_accessor :backtrace_filter

  def initialize(config = {})
    @config = config
    @template = ERB.new(TEMPLATE)

    @backtrace_filter = -> line { true }
  end

  def _notify(exception, options = {})
    body = @template.result(binding)

    Net::SMTP.start(@config.fetch(:host), @config.fetch(:port, 25)) do |smtp|
      smtp.send_message(body, @config.fetch(:from), @config.fetch(:to))
    end
  end

  def notify(exception, options = {})
    begin
      _notify(exception, options)
    rescue => notification_error
      $stderr.write("*** FAILED SENDING ERROR NOTIFICATION\n")
      $stderr.write("*** #{notification_error.class}: #{notification_error}\n")
      $stderr.write("*** #{exception.class}: #{exception.message}\n")

      exception.backtrace.each do |line|
        $stderr.write("*** #{line}\n")
      end
    end
  end

  TEMPLATE = (<<-'EMAIL').gsub(/^ {2}/, '')
  From: <%= @config[:from_alias] %> <<%= @config[:from] %>>
  To: <<%= @config[:to] %>>
  Subject: <%= exception.class %>: <%= exception.message.split.join(" ") %>

  <%= options[:body] %>

  <%= "~" * 80 %>

  A <%= exception.class.to_s %> occured: <%= exception.to_s %>

  <%= exception.backtrace.select { |line| @backtrace_filter.call(line) }.join("\n") if exception.backtrace %>
  EMAIL

  class Middleware
    def initialize(app, config = {})
      @app = app
      @notifier = ExceptionNo.new(config)
    end

    def call(env)
      begin
        @app.call(env)
      rescue Exception => e
        @notifier.notify(e, body: extract_env(env))

        raise e
      end
    end

    def extract_env(env)
      req = Rack::Request.new(env)

      parts = []

      parts << "#{req.request_method} #{req.url}"
      parts << "User-Agent: #{req.user_agent}" if req.user_agent
      parts << "Referrer: #{req.referrer}" if req.referrer
      parts << "Cookie: #{req.env["HTTP_COOKIE"]}" if req.cookies.size > 0

      parts.join("\n")
    end
  end
end
