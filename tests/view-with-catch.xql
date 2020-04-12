xquery version "3.1";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace templates-lookup="https://tools.ietf.org/html/rfc7807/tests/lookup" at "templates-lookup.xqm";

(: The following modules provide functions which will be called by the templating :)
import module namespace test="https://tools.ietf.org/html/rfc7807/tests" at "api-problem-rest-test.xqm";
import module namespace api-problem="https://tools.ietf.org/html/rfc7807" at "../api-problem.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

let $config := map {
    $templates:CONFIG_APP_ROOT : '/db/apps/api-problem/tests/'
}

let $content := request:get-data()
return
    try { 
        templates:apply($content, templates-lookup:resolve#2, (), $config)
    } catch * {
        (: There are two options here:
             * use an error-handler in controller.xql that also catches problems in error handling here
               or 401 errors
               -> you have to report errors as rfc7807:problem ($accept := 'application/xml'),
                  final rendering is done by catch-all-handler.xql :)
        let $accept := 'application/xml',
            $api-problem-restxq := api-problem:error-handler(
              $err:code, $err:description, $err:value, 
              $err:module, $err:line-number, $err:column-number,
              $exerr:xquery-stack-trace, $exerr:java-stack-trace,
              $accept, '')
            return (
                api-problem:set-status-and-headers-like-restxq($api-problem-restxq[1]),
                (: we need to be sure to set the serialization parameters regardless of eventually set option in the prolog :)
                response:stream($api-problem-restxq, 'method=xml media-type=application/xml')
            )
        (:   * don't use an error handler in controller.xql and do the final rendering in your here
        let $accept := request:get-header('Accept'),
            $api-problem-restxq := api-problem:error-handler(
              $err:code, $err:description, $err:value, 
              $err:module, $err:line-number, $err:column-number,
              $exerr:xquery-stack-trace, $exerr:java-stack-trace,
              $accept, request:get-header('Origin')),
            $error-template := doc($config($templates:CONFIG_APP_ROOT)||'/error-page.html'),
            $error-render-function := function($error-template  as element(), $api-problem as element()) {
                templates:apply($error-template, $lookup, map {$api-problem:DATA: $api-problem}, $config)
            },
            $output := (
                api-problem:set-status-and-headers-like-restxq($api-problem-restxq[1]),
                api-problem:render-output-according-to-accept($accept, $error-template, $api-problem-restxq, $error-render-function)
            ) 
        return response:stream($output, api-problem:get-stream-serialization-options($output, $api-problem-restxq)) :)
    }