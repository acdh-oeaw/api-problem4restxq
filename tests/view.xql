xquery version "3.1";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace templates-lookup="https://tools.ietf.org/html/rfc7807/tests/lookup" at "templates-lookup.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "xhtml";
declare option output:media-type "text/html";

let $config := map {
    $templates:CONFIG_APP_ROOT : '/db/apps/api-problem/tests/'
}

let $content := request:get-data()
return
    templates:apply($content, templates-lookup:resolve#2, map {'request.header.accept': request:get-header('Accept')}, $config)
