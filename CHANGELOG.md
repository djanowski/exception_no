0.0.4 - unreleased
==================

* Added `ExceptionNo#run` which takes a block and notifies about errors.

0.0.3 - 2013-09-18
==================

* `ExceptionNo#deliver` can be used to control whether or not to send email
  notifications. Typically useful in a non-production environment.

0.0.2 - 2013-09-17
==================

* `Middleware` now requires an explicit `ExceptionNo` instance.

  This makes it easier to reuse your `ExceptionNo` instance in other parts of
  your application.

0.0.1 - 2013-09-17
==================

* First release.
