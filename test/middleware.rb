require_relative "prelude"

require "rack"

setup do
  Rack::Builder.new do |builder|
    builder.use ExceptionNo::Middleware,
      ExceptionNo.new(
        host: "127.0.0.1",
        port: 2525,
        to: "root@localhost",
        from: "service@localhost"
      )

    builder.run(-> env { 1 / 0 })
  end
end

test "re-raises exceptions" do |app|
  assert_raise(ZeroDivisionError) { app.call(Rack::MockRequest.env_for("/")) }
end

test "extracts interesting stuff from the request" do |app|
  env = Rack::MockRequest.env_for(
    "/baz",
    "HTTP_USER_AGENT" => "Mozilla/4.0 (compatible)",
    "HTTP_REFERER"    => "/other",
    "HTTP_COOKIE"     => "foo=bar",
    "REMOTE_ADDR"     => "127.0.0.2",
  )

  begin
    app.call(env)
  rescue ZeroDivisionError
  end

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert_equal headers["Subject"], "ZeroDivisionError: divided by 0"
  assert body.include?("GET http://example.org/baz\r\n")
  assert body.include?("User-Agent: Mozilla/4.0 (compatible)")
  assert body.include?("Referrer: /other")
  assert body.include?("Cookie: foo=bar")
  assert body.include?("IP: 127.0.0.2")
end

test "extracts the posted form" do |app|
  env = Rack::MockRequest.env_for(
    "/baz",
    "REQUEST_METHOD" => "POST",
    input: "foo=bar&baz=qux",
  )

  begin
    app.call(env)
  rescue ZeroDivisionError
  end

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert_equal headers["Subject"], "ZeroDivisionError: divided by 0"
  assert body.include?("POST http://example.org/baz\r\n")
  assert body.include?(%Q[  {"foo"=>"bar", "baz"=>"qux"}])
end

test "extracts the request body" do |app|
  env = Rack::MockRequest.env_for(
    "/baz",
    "REQUEST_METHOD" => "POST",
    "CONTENT_TYPE" => "text/plain; charset=utf-8",
    input: "foo:bar",
  )

  begin
    app.call(env)
  rescue ZeroDivisionError
  end

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert_equal headers["Subject"], "ZeroDivisionError: divided by 0"
  assert body.include?("POST http://example.org/baz\r\n")
  assert body.include?(%Q[  foo:bar])
end

test "doesn't raise when the notification fails" do |app|
  app = Rack::Builder.new do |builder|
    builder.use ExceptionNo::Middleware,
      ExceptionNo.new(
        host: "127.0.0.1",
        port: 2526,
        to: "root@localhost",
        from: "service@localhost"
      )

    builder.run(-> env { 1 / 0 })
  end

  env = Rack::MockRequest.env_for(
    "/baz",
    "HTTP_USER_AGENT" => "Mozilla/4.0 (compatible)",
    "HTTP_REFERER"    => "/other",
    "HTTP_COOKIE"     => "foo=bar",
  )

  assert_raise(ZeroDivisionError) do
    capture_stderr do
      app.call(env)
    end
  end
end

test "allows for env sanitization before notifying" do
  app = Rack::Builder.new do |builder|
    builder.use ExceptionNo::Middleware,
      ExceptionNo.new(
        host: "127.0.0.1",
        port: 2525,
        to: "root@localhost",
        from: "service@localhost",
      ),
      sanitizer: -> payload do
        if payload.kind_of?(String)
          payload.sub(/credit_card:(\d+)/, "credit_card:masked")
        else
          payload.merge("credit_card" => "masked")
        end
      end

    builder.run(-> env { 1 / 0 })
  end

  env = Rack::MockRequest.env_for(
    "/baz",
    "REQUEST_METHOD" => "POST",
    input: "foo=bar&credit_card=12345",
  )

  begin
    app.call(env)
  rescue ZeroDivisionError
  end

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert body.include?(%Q[  {"foo"=>"bar", "credit_card"=>"masked"}])
  assert !body.include?("12345")

  env = Rack::MockRequest.env_for(
    "/baz",
    "REQUEST_METHOD" => "POST",
    "CONTENT_TYPE" => "text/plain; charset=utf-8",
    input: "foo:bar, credit_card:12345",
  )

  begin
    app.call(env)
  rescue ZeroDivisionError
  end

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert body.include?(%Q[  foo:bar, credit_card:masked])
  assert !body.include?("12345")
end
