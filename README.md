An API Problem implementation
=============================

This module implements easy to use [RFC 7808](https://tools.ietf.org/html/rfc7807)
error reporting from RestXQ functions. This can be as easy as raisng a specifically crafted error.

Building
--------

build a installable XAR using

```bash
ant
```

Minimum exist-db version required
------------------------------

Usage
-----

* Use `api-problem.xqm` as a module and wrap calls to your RestXQ code in a function
  `api-problem:or_result()`
* Add the following to your `web.xml`
  After that you need to restart.
  
```xml
<error-page>
    <location>/rest/db/apps/api-problem/catch-all-handler.xql</location>
</error-page>
```

Demos and tests
---------------

Look into the test directory to see possible usage scenarios.

There is a demo web page that opens when you click on the package icon in dashboard.
