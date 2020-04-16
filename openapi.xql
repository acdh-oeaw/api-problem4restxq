xquery version "3.1";

import module namespace openapi="https://lab.sub.uni-goettingen.de/restxqopenapi" at "../openapi/content/openapi.xqm";
import module namespace console="http://exist-db.org/xquery/console";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

let $target := replace(system:get-module-load-path(),
'^(xmldb:exist://)?(embedded-eXist-server)?(.+)$', '$3')
  , $log := console:log($target)
return openapi:main($target)