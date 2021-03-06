# encoding: utf-8

require_relative "prelude"

setup do
  ExceptionNo.new(
    host: "127.0.0.1",
    port: 2525,
    to: "root@localhost",
    from: "service@localhost"
  )
end

test "deliver exception notification" do |notifier|
  notifier.behaviors = [:deliver]

  ex = ArgumentError.new("Really bad argument")

  notifier.notify(ex)

  email = $smtp.outbox.pop

  assert_equal email[:to], "<root@localhost>"
  assert_equal email[:from], "<service@localhost>"

  headers, body = parse_email(email[:data])

  assert_equal headers["Subject"], "ArgumentError: Really bad argument"
  assert body.include?("A ArgumentError occured: Really bad argument")
end

test "exception messages with multiple lines" do |notifier|
  notifier.behaviors = [:deliver]

  notifier.notify(ArgumentError.new("A really\nbad\nargument"))

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert_equal headers["Subject"], "ArgumentError: A really bad argument"
end

test "includes backtrace information" do |notifier|
  notifier.behaviors = [:deliver]

  begin
    raise ArgumentError, "A bad argument"
  rescue Exception => ex
    notifier.notify(ex)
  end

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert body.include?(__FILE__)
  assert body.include?(Gem.path.first)
end

test "allows to filter the backtrace" do |notifier|
  notifier.behaviors = [:deliver]

  notifier.backtrace_filter = -> line do
    !line.include?(Gem.path.first)
  end

  begin
    raise ArgumentError, "A bad argument"
  rescue Exception => ex
    notifier.notify(ex)
  end

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert body.include?(__FILE__)
  assert !body.include?(Gem.path.first)
end

test "disable delivery" do |notifier|
  notifier.behaviors = []

  notifier.notify(ArgumentError.new)

  assert_raise(QueueWithTimeout::Timeout) do
    $smtp.outbox.pop(0.5)
  end
end

test "raise exception" do |notifier|
  notifier.behaviors = [:raise]

  assert_raise(ArgumentError) { notifier.notify(ArgumentError.new) }

  assert_raise(QueueWithTimeout::Timeout) do
    $smtp.outbox.pop(0.5)
  end
end

test "raise exception and deliver notification" do |notifier|
  notifier.behaviors = [:raise, :deliver]

  assert_raise(ArgumentError) { notifier.notify(ArgumentError.new) }

  assert $smtp.outbox.pop
end

test "block behavior" do |notifier|
  notifier.behaviors = [:deliver]

  notifier.run do
    raise ArgumentError, "A bad argument"
  end

  assert $smtp.outbox.pop
end

test "block with environment" do |notifier|
  notifier.behaviors = [:deliver]

  notifier.run("Foo" => "Bar") do
    raise ArgumentError, "A bad argument"
  end

  headers, body = parse_email($smtp.outbox.pop[:data])

  assert body.include?("Foo: Bar")
end

test "UTF-8 encoding" do |notifier|
  ex = ArgumentError.new("Aló")

  notifier.notify(ex)

  assert $smtp.outbox.pop
end
