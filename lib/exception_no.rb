# encoding: utf-8

require "net/smtp"
require "erb"
require "pp"

class ExceptionNo
  VERSION = "0.0.7"

  attr_accessor :backtrace_filter
  attr_accessor :behaviors

  def initialize(config = {})
    @config = config
    @template = ERB.new(TEMPLATE)
    @behaviors = [:deliver]

    @backtrace_filter = -> line { true }
  end

  def _deliver(exception, env = {})
    body = @template.result(binding)

    Net::SMTP.start(@config.fetch(:host), @config.fetch(:port, 25)) do |smtp|
      smtp.send_message(body, @config.fetch(:from), @config.fetch(:to))
    end
  end

  def deliver(exception, options)
    begin
      _deliver(exception, options)
    rescue => notification_error
      $stderr.write("*** FAILED SENDING ERROR NOTIFICATION\n")
      $stderr.write("*** #{notification_error.class}: #{notification_error}\n")
      $stderr.write("*** #{exception.class}: #{exception.message}\n")

      exception.backtrace.each do |line|
        $stderr.write("*** #{line}\n")
      end
    end
  end

  def notify(exception, options = {})
    deliver(exception, options) if @behaviors.include?(:deliver)
    raise exception if @behaviors.include?(:raise)
  end

  def run(env = {})
    begin
      yield
    rescue Exception => ex
      notify(ex, env)
    end
  end

  TEMPLATE = (<<-'EMAIL').gsub(/^ {2}/, '')
  From: <%= @config[:from_alias] %> <<%= @config[:from] %>>
  To: <<%= @config[:to] %>>
  Subject: <%= exception.class %>: <%= exception.message.split.join(" ") %>

  <%= env.map { |*parts| parts.join(": ") }.join("\n") %>

  <%= "~" * 80 %>

  A <%= exception.class.to_s %> occured: <%= exception.to_s %>

  <%= exception.backtrace.select { |line| @backtrace_filter.call(line) }.join("\n") if exception.backtrace %>
  EMAIL

  class Middleware
    def initialize(app, notifier, options = {})
      @app = app
      @notifier = notifier
      @sanitizer = options.fetch(:sanitizer, -> _ { _ })
    end

    def call(env)
      begin
        @app.call(env)
      rescue Exception => e
        @notifier.notify(e, extract_env(env))

        raise e
      end
    end

    def extract_env(env)
      req = Rack::Request.new(env)

      parts = []

      parts << "#{req.request_method} #{req.url}"
      parts << "User-Agent: #{req.user_agent}" if req.user_agent
      parts << "Referrer: #{req.referrer}" if req.referrer
      parts << "IP: #{req.ip}" if req.ip
      parts << "Cookie: #{req.env["HTTP_COOKIE"]}" if req.cookies.size > 0

      if req.form_data?
        body = @sanitizer.call(req.POST).pretty_inspect
      else
        req.body.rewind

        body = req.body.read

        if body.empty?
          body = nil
        else
          body = @sanitizer.call(body)
        end
      end

      if body
        parts << "Body: \n\n#{body.gsub(/^/, "  ")}"
      end

      parts
    end
  end
end
