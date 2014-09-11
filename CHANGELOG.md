0.0.6 - 2014-09-11
==================

* The middleware now accepts a `:sanitizer` proc that filters the environment
  for sensitive parameters before notifying (e.g. credit card numbers).

0.0.5 - 2014-09-10
==================

* The middleware now extracts the request IP address.

* The middleware now extracts the request body.

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
