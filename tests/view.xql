xquery version "3.1";

import module namespace templates="http://exist-db.org/xquery/templates";

(: The following modules provide functions which will be called by the templating :)
import module namespace test="https://tools.ietf.org/html/rfc7807/tests" at "api-problem-rest-test.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "xhtml";
declare option output:media-type "text/html";

let $config := map {
    $templates:CONFIG_APP_ROOT : '/db/apps/api-problem/tests/'
}
let $lookup := function($functionName as xs:string, $arity as xs:int) {
    function-lookup(xs:QName($functionName), $arity)
    (: we have a catch all elsewhere :)
}

let $content := request:get-data()
return
    templates:apply($content, $lookup, map {'request.header.accept': request:get-header('Accept')}, $config)
