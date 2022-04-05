# Helper module for RESTful APIs

The module `api-problem.xqm` is a helper that allows you to report errors to the REST API
user by simply using the `error()` function with a special URI.
This should help keep your code clean.
The errors are structured as described in [RFC 7807](https://datatracker.ietf.org/doc/html/rfc7807).
A HTTP Accept header based switch between JSON and XML is implemented.

## How to use

This is not a packaged module. You probably should copy `api-problem.xqm` to your source code.
Please not that by default this declares a default error handler and you can have only one of them.

## Documentation and tests

There is not much documentation yet. But you can see the JS side as well as
how to utilize the module in the `tests` directory.
