xquery version "3.1";

let $targetCollection := '/db/apps/api-problem'
let $chmod := (
  for $html in xmldb:get-child-resources($targetCollection)[ends-with(., '.html')]
    return sm:chmod(xs:anyURI($targetCollection || '/' || $html), 'r--r--r--'),
  for $html in xmldb:get-child-resources($targetCollection||'/tests')[ends-with(., '.html')]
    return sm:chmod(xs:anyURI($targetCollection || '/tests/' || $html), 'r--r--r--'),
  sm:chmod(xs:anyURI($targetCollection || '/tests/access-denied.html'), 'r--------'),
  for $xqm in xmldb:get-child-resources($targetCollection)[ends-with(., '.xqm')]
    return sm:chmod(xs:anyURI($targetCollection || '/' || $xqm), 'r--r--r--'),
  for $xqm in xmldb:get-child-resources($targetCollection||'/tests')[ends-with(., '.xqm')]
    return sm:chmod(xs:anyURI($targetCollection || '/tests/' || $xqm), 'r--r--r--'),
  sm:chmod(xs:anyURI($targetCollection || '/tests/api-problem-rest-test.xqm'), 'rwxr-xr-x'),
  for $xql in xmldb:get-child-resources($targetCollection)[ends-with(., '.xql')]
    return sm:chmod(xs:anyURI($targetCollection || '/' || $xql), 'r-xr-xr-x'),
  sm:chmod(xs:anyURI($targetCollection || '/post-install.xql'), 'r--------'),
  for $xql in xmldb:get-child-resources($targetCollection || '/tests')[ends-with(., '.xql') or ends-with(., '.xq')]
    return sm:chmod(xs:anyURI($targetCollection || '/tests/' || $xql), 'r-xr-xr-x')
)

return $chmod