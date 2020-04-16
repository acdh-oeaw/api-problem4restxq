xquery version "3.1";

(: file path pointing to the eXist-db installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external := '/db/apps/api-problem';

let $chmod := (
  for $html in xmldb:get-child-resources($target)[ends-with(., '.html') or ends-with(., '.js')]
    return sm:chmod(xs:anyURI($target || '/' || $html), 'r--r--r--'),
  for $html in xmldb:get-child-resources($target||'/tests')[ends-with(., '.html')]
    return sm:chmod(xs:anyURI($target || '/tests/' || $html), 'r--r--r--'),
  sm:chmod(xs:anyURI($target || '/tests/access-denied.html'), 'r--------'),
  for $xqm in xmldb:get-child-resources($target)[ends-with(., '.xqm')]
    return sm:chmod(xs:anyURI($target || '/' || $xqm), 'r--r--r--'),
  for $xqm in xmldb:get-child-resources($target||'/tests')[ends-with(., '.xqm')]
    return sm:chmod(xs:anyURI($target || '/tests/' || $xqm), 'r--r--r--'),
  sm:chmod(xs:anyURI($target || '/tests/api-problem-rest-test.xqm'), 'rwxr-xr-x'),
  for $xql in xmldb:get-child-resources($target)[ends-with(., '.xql')]
    return sm:chmod(xs:anyURI($target || '/' || $xql), 'r-xr-xr-x'),
  sm:chmod(xs:anyURI($target || '/post-install.xql'), 'r--------'),
  for $xql in xmldb:get-child-resources($target || '/tests')[ends-with(., '.xql') or ends-with(., '.xq')]
    return sm:chmod(xs:anyURI($target || '/tests/' || $xql), 'r-xr-xr-x')
)

return $chmod