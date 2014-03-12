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
  notifier.behaviours = [:deliver]

  ex = ArgumentError.new("Really bad argument")

  notifier.notify(ex)

  email = $smtp.outbox.last

  assert_equal email[:to], "<root@localhost>"
  assert_equal email[:from], "<service@localhost>"

  headers, body = parse_email(email[:data])

  assert_equal headers["Subject"], "ArgumentError: Really bad argument"
  assert body.include?("A ArgumentError occured: Really bad argument")
end

test "exception messages with multiple lines" do |notifier|
  notifier.behaviours = [:deliver]

  notifier.notify(ArgumentError.new("A really\nbad\nargument"))

  headers, body = parse_email($smtp.outbox.last[:data])

  assert_equal headers["Subject"], "ArgumentError: A really bad argument"
end

test "includes backtrace information" do |notifier|
  notifier.behaviours = [:deliver]

  begin
    raise ArgumentError, "A bad argument"
  rescue Exception => ex
    notifier.notify(ex)
  end

  headers, body = parse_email($smtp.outbox.last[:data])

  assert body.include?(__FILE__)
  assert body.include?(Gem.path.first)
end

test "allows to filter the backtrace" do |notifier|
  notifier.behaviours = [:deliver]

  notifier.backtrace_filter = -> line do
    !line.include?(Gem.path.first)
  end

  begin
    raise ArgumentError, "A bad argument"
  rescue Exception => ex
    notifier.notify(ex)
  end

  headers, body = parse_email($smtp.outbox.last[:data])

  assert body.include?(__FILE__)
  assert !body.include?(Gem.path.first)
end

test "disable delivery" do |notifier|
  notifier.behaviours = []

  notifier.notify(ArgumentError.new)

  assert_equal $smtp.outbox.size, 0
end

test "raise exception" do |notifier|
  notifier.behaviours = [:raise]

  assert_raise(ArgumentError) { notifier.notify(ArgumentError.new) }

  assert_equal $smtp.outbox.size, 0
end

test "raise exception and deliver notification" do |notifier|
  notifier.behaviours = [:raise, :deliver]

  assert_raise(ArgumentError) { notifier.notify(ArgumentError.new) }

  assert_equal $smtp.outbox.size, 1
end

$smtp.stop
$smtp.join
