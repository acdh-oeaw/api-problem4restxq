xquery version "3.1";

import module namespace api-problem = "https://tools.ietf.org/html/rfc7807" at "api-problem.xqm";
import module namespace templates = "http://exist-db.org/xquery/templates";
import module namespace console="http://exist-db.org/xquery/console";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace hc="http://expath.org/ns/http-client";

declare function local:render-template($template, $api-problem) {
  
let $config := map {
    $templates:CONFIG_APP_ROOT : '/db/apps/api-problem/tests/'
}

let $lookup := function($functionName as xs:string, $arity as xs:int) {
    function-lookup(xs:QName($functionName), $arity)
    (: we have a catch all elsewhere :)
}

return
    templates:apply($template, $lookup, map {$api-problem:DATA: $api-problem}, $config)
};

declare function local:respond() {
    let $parsed := if (exists(request:get-attribute('org.exist.forward.error'))) 
           then local:parse-exception-forward(parse-xml(request:get-attribute('org.exist.forward.error'))/*)
           else if (exists(request:get-attribute('javax.servlet.error.message')))
             then local:parse-javax-message(request:get-attribute('javax.servlet.error.message'))
             else local:empty-is-probably-401(),
(:        $log := console:log($parsed),:)
        $template := request:get-data()/*,
        $should-render := (
          $template instance of element() and $template/namespace-uri() = 'http://www.w3.org/1999/xhtml' and
          matches(request:get-header('Accept'), 'application/xhtml\+xml')),
        $api-problem := api-problem:error-handler($parsed('code'), $parsed('description'), '', $parsed('module'), $parsed('line-number'), $parsed('column-number'), $parsed('additional'), request:get-header('Accept'), request:get-header("Origin")),
(:        $log := console:log($api-problem[1]),:)
        $status := response:set-status-code($api-problem[1]/hc:response/@status),
        $headers := for $header in $api-problem[1]/hc:response/hc:header[not(@name=('Content-Type'))] return response:set-header($header/@name, $header/@value),
        $output := switch (true())
          case $api-problem[1]/output:serialization-parameters/output:method/@value/data() = 'json' return serialize($api-problem[2], map{'method': 'json'})
          case $should-render return (response:set-header('Content-Type', 'text/html'), local:render-template($template, $api-problem[2]))
          default return $api-problem[2],
        $serialization-options := switch (true())
          case $api-problem[1]/output:serialization-parameters/output:method/@value/data() = 'json' return 'method=text'
          case $should-render return 'method=xhtml'
          default return string-join(for $param in $api-problem[1]/output:serialization-parameters/* return concat($param/local-name(), '=', $param/@value), ' '),
        $serialization-options := if ($should-render) then $serialization-options||' media-type=text/html'
          else $serialization-options||' media-type='||$api-problem[1]/hc:response/hc:header[@name='Content-Type']/@value
(:      , $log := (console:log($output), console:log($serialization-options)):)
    return response:stream($output,  $serialization-options)
(:      return local:debug-out($api-problem[1], $output, $parsed, $serialization-options||'&#x0a;'||string-join(for $header in $api-problem[1]/hc:response/hc:header return $header/@name||'='||$header/@value, '&#x0a;')):)
};

declare function local:parse-javax-message($message as xs:string?) as map(*) {
  let $res := analyze-string($message, 'An error occurred[^:]+:\s([^:]+:[^ ]+)\s(.+)( \[at line (\d+), column (\d+)(, source: ([^\[]+))?\])(&#x0a;In function:(&#x0a;.*))?', 'sm'),
      $module := if (exists($res//*:group[@nr=7]) or exists($res//*:group[@nr=9]))
              then xs:string($res//*:group[@nr=7])
              else if (request:get-attribute('javax.servlet.error.servlet_name') = 'XQueryURLRewrite') 
                then concat('/db', request:get-attribute('$exist:prefix'), request:get-attribute('$exist:controller'), '/controller.xql')
                else request:get-attribute('javax.servlet.error.servlet_name')
  return map {
    'code': if (exists($res//*:group[@nr=1])) 
            then xs:string($res//*:group[@nr=1])
            else concat('response-codes:_',request:get-attribute('javax.servlet.error.status_code')),
    'description': if (exists($res//*:group[@nr=1])) 
                   then xs:string($res//*:group[@nr=2])
                   else $message,
    'value': serialize($res),
    'module': $module,
    'line-number': if (exists($res//*:group[@nr=4])) then xs:string($res//*:group[@nr=4]) else 0,
    'column-number': if (exists($res//*:group[@nr=5])) then xs:string($res//*:group[@nr=5]) else 0,
    'additional': api-problem:fix-stack(tokenize($res//*:group[@nr=9], '&#x0a;'), $module, $res//*:group[@nr=4], $res//*:group[@nr=5])
  }
};

declare function local:parse-exception-forward($exception as element(exception)) as map(*) {
    let $res := analyze-string($exception/message, '([^:]+:[^ ]+)\s(.+)( \[at line (\d+), column (\d+)(, source: ([^\[]+))?\])(&#x0a;In function:(&#x0a;.*))?', 'sm'),
        $module := xs:string($exception/path)
    return map {
    'code': if (exists($res//*:group[@nr=1])) 
            then xs:string($res//*:group[@nr=1])
            else concat('response-codes:_',request:get-attribute('javax.servlet.error.status_code')),
    'description': if (exists($res//*:group[@nr=1])) 
                   then xs:string($res//*:group[@nr=2])
                   else xs:string($exception/message),
    'value': serialize($res),
    'module': $module,
    'line-number': if (exists($res//*:group[@nr=4])) then xs:string($res//*:group[@nr=4]) else 0,
    'column-number': if (exists($res//*:group[@nr=5])) then xs:string($res//*:group[@nr=5]) else 0,
    'additional': api-problem:fix-stack(tokenize($res//*:group[@nr=9], '&#x0a;'), $module, $res//*:group[@nr=4], $res//*:group[@nr=5])
  }    
};

declare function local:empty-is-probably-401() {
  map {
      'code': 'response-codes:_401',
      'description': $api-problem:codes_to_message(401),
      'value': 'Most probably 401. exist-db does not provide any data if this is the error',
      'line-number': 0,
      'column-number': 0,
      'additional': ''
  }  
};

declare function local:debug-out($api-problem-1 as item(), $output, $parsed, $serialization-options) {
    response:stream( 
        <html> 
            <head> 
                <title>Resource not found</title> 
            </head> 
            <body> 
                <h1>Resource not found</h1> 
                <p>{request:get-uri()} does not exist</p>
                <h2>Parsed</h2>
                {(
                    <ul>
                        <li>code: {$parsed('code')}</li>
                        <li>description: {$parsed('description')}</li>
                        <li>value:{$parsed('value')} </li>
                        <li>module: {$parsed('module')}</li>
                        <li>line-number: {$parsed('line-number')}</li>
                        <li>column-number: {$parsed('column-number')}</li>
                        <li>additional: {$parsed('additional')}</li>
                    </ul>,
                    $serialization-options,
                    <pre>
                        {serialize($api-problem-1, map {'indent': true()})}
                        {serialize($output, map {'indent': true()})}
                    </pre>
                    )
                   }
                <h2>Controller Environment</h2>
                    <ul>
                        {for $name in request:attribute-names()[starts-with(., '$exist:')]
                           return <li>{$name} = {request:get-attribute($name)}</li>
                        } 
                    </ul>
                <h2>Attributes</h2>
                    <ul>
                        {for $name in request:attribute-names()[not(starts-with(., '$exist:'))]
                           return <li>{$name} = {request:get-attribute($name)}</li>
                        }
                    </ul>
                <h2>Headers</h2>
                    <ul>
                        {for $name in request:get-header-names()
                           return <li>{$name} = {request:get-header($name)}</li>
                        }
                    </ul>
                <h2>Parameters</h2>
                    <ul>
                        {for $name in request:get-parameter-names()
                           return <li>{$name} = {request:get-parameter($name, ())}</li>
                        }
                    </ul>
                <h2>Data</h2>
                <pre>{serialize(request:get-data())}</pre>
            </body> 
        </html>, 
    'method=html media-type=text/html indent=no')     
};

(: Setting a status code in an error-handler for script invocations triggers the error handler a second time.
 : Additionally any xml returned from the first invocation is reparsed in a strange way setting lots of prefixes.
 :)
if (exists(request:get-attribute('org.exist.forward.error')) and
    exists(request:get-attribute('api-problem.set-status-code.workaround')) and
    not(exists(request:get-attribute('api-problem.set-status-code.workaround.respond')))) then
    let $respond-in-next-invocation := request:set-attribute('api-problem.set-status-code.workaround.respond', 'true'),
        $trigger-second-invocation := response:set-status-code(999)
    return request:get-attribute('org.exist.forward.error')
else
    (: 401 responses due to exist-db's access control system act really strange.
     : They have a fixed Content-Type and fixed unusual serialization. (forces prefixes declared here,
     : no way tho change content type)
     : The next lines try to at least provide the corrct body although with this kind of serialization
     : browsers and JS libraries will not deal with this gracefully.
     :)
    try { local:respond() }
    catch java:org.exist.xquery.XPathException | err:FODC0006 {
        try { parse-xml(request:get-attribute('org.exist.forward.error')) }
        catch err:FODC0006 {request:get-attribute('org.exist.forward.error')}
    }