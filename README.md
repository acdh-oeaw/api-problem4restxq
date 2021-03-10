An API Problem implementation
=============================

This module implements easy to use [RFC 7808](https://tools.ietf.org/html/rfc7807)
error reporting from RestXQ functions. This can be as easy as raisng a specifically crafted error.

Minimum BaseX version required
------------------------------

This works with BaseX 9.1.0 and up.
In 9.0.2 there is a problem with `web:response-header()` which has a workaround
but it is not included here.
With replacements for convenience function this probably is usabel in 8.x.y.

Usage
-----

* Add api-problem.xqm to your code in the `webapp` directory.
  This installs a catch all error handler that formats errors according to RFC 7808
  in either XML or JSON representation depending on the accept header.
* Use this as a module and wrap calls to your RestXQ code in a function
  `api-problem:or_result()`

Demos and tests
---------------

Look into the test directory to see possible usage scenarios.

If you download `git clone` this repository into your `webapp` directory
a demo page in `/api-problem-tests` will be available. There is a small mocha based
test suite that you can try and run with `yarn install` `yarn run test` (or npm).
