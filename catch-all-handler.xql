xquery version "3.1";

import module namespace api-problem = "https://tools.ietf.org/html/rfc7807" at "api-problem.xqm";
import module namespace templates = "http://exist-db.org/xquery/templates";
import module namespace console="http://exist-db.org/xquery/console";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace hc="http://expath.org/ns/http-client";

declare function local:render-template($template, $api-problem) {

(:console:log('Using api-problem in template rendering.'),:)
let $config := map {
    $templates:CONFIG_APP_ROOT : (
        request:get-attribute('templates.app-root'),
        (: Needs to be hardcoded when this is called as error-page. Adjust if necessary.
         : See $lookup and $template below.
         :)
        '/db/apps/api-problem/tests'
    )[1]
}

(:let $log := (console:log($config), console:log(request:get-attribute('templates.lookup-module'))):)

(: This is a suggested method to share the template function resolver
 : between view.xql and catch-all-handler.xql.
 : catch-all-handler.xql gets a customize version of this module by
 : reading the templates.lookup-module attribute and uses the first
 : method in that module.
 : If invoked by web.xml error-page there is a hard coded alternative.
 :)

let $lookup := (
    if (exists(request:get-attribute('templates.lookup-module')))
    then try {
        inspect:module-functions(xs:anyURI(request:get-attribute('templates.lookup-module')))
    } catch * { () }
    else (),
    inspect:module-functions(xs:anyURI('/db/apps/api-problem/tests/templates-lookup.xqm'))
    )[1]

return
    templates:apply($template, $lookup, map {$api-problem:DATA: $api-problem}, $config)
};

declare function local:respond($accept as xs:string) {
    let $parsed := if (exists(request:get-attribute('org.exist.forward.error'))) 
           then 
              let $forwarded-xml := parse-xml-fragment(
                  replace(request:get-attribute('org.exist.forward.error'), '^<\?xml\sversion="1.0"\s?\?>', '', 'm') =>
                  replace('<!DOCTYPE html>', '', 'm'))
                  (: workaround before 5.3: parse-xml-fragment does not return document-node (standard) :)
                , $forwarded-xml := if ($forwarded-xml instance of document-node()) then $forwarded-xml/* else $forwarded-xml
              return switch(true())
                case $forwarded-xml instance of element(exception) return local:parse-exception-forward($forwarded-xml)
                case $forwarded-xml instance of element()+ and $forwarded-xml[2]/local-name() = 'problem' return local:forwarded-problem($forwarded-xml) 
                default return (
                    console:log($forwarded-xml),
                    error(xs:QName('local:unrecognized-xml'), 'Can not process this kind of XML: '||
                    string-join($forwarded-xml!./local-name(), ', '))
                )
           else if (exists(request:get-attribute('javax.servlet.error.message')))
             then local:parse-javax-message(request:get-attribute('javax.servlet.error.message'))
             else local:empty-is-probably-401(),
(:        $log := console:log($parsed), :)
        $template := (
            request:get-data()/*,
            (: As above: needs to be hardcoded when this is called as error-page. Adjust if necessary. :)
            doc('/db/apps/api-problem/tests/error-page.html')/*
        )[1],
        $api-problem-restxq := api-problem:error-handler($parsed('code'), $parsed('description'), $parsed('value'), $parsed('module'), $parsed('line-number'), $parsed('column-number'), $parsed('additional'), (), $accept, request:get-header("Origin")),
        $output := (api-problem:set-status-and-headers-like-restxq($api-problem-restxq[1]),
          if ($accept = 'application/restxq+xml') then $api-problem-restxq
          else api-problem:render-output-according-to-accept($accept, $template, $api-problem-restxq, local:render-template#2))
(:      , $log := (console:log($output), console:log($accept||': '||api-problem:get-stream-serialization-options($output, $api-problem-restxq))):)
    return response:stream($output,  api-problem:get-stream-serialization-options($output, $api-problem-restxq))
(:      return local:debug-out($api-problem-restxq[1], $output, $parsed, api-problem:get-stream-serialization-options($output, $api-problem-restxq)||'&#x0a;'||string-join(for $header in $api-problem-restxq[1]/hc:response/hc:header return $header/@name||'='||$header/@value, '&#x0a;')):)
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
    'value': request:get-attribute('api-problem.requested-filename'),
    'module': $module,
    'line-number': if (exists($res//*:group[@nr=4])) then xs:integer($res//*:group[@nr=4]) else 0,
    'column-number': if (exists($res//*:group[@nr=5])) then xs:integer($res//*:group[@nr=5]) else 0,
    'additional': tokenize($res//*:group[@nr=9], '&#x0a;'),
    'analyze-string': serialize($res)
  }
};

declare function local:parse-exception-forward($exception as element(exception)) as map(*) {
    let $res := analyze-string($exception/message, '(([^:]+:)?[^ ]+)\s(.+)( \[at line (\d+), column (\d+)(, source: ([^\[]+))?\])(&#x0a;In function:(&#x0a;.*))?', 'sm'),
        $module := xs:string($exception/path)
    return map {
    'code': if (exists($res//*:group[@nr=1])) 
            then xs:string($res//*:group[@nr=1])
            else if (request:get-attribute('javax.servlet.error.status_code') castable as xs:integer)
              then concat('response-codes:_',request:get-attribute('javax.servlet.error.status_code'))
              else 'response-codes:_500',
    'description': if (exists($res//*:group[@nr=1])) 
                   then xs:string($res//*:group[@nr=3])
                   else xs:string($exception/message),
    'value': '',
    'module': $module,
    'line-number': if (exists($res//*:group[@nr=5])) then xs:integer($res//*:group[@nr=5]) else 0,
    'column-number': if (exists($res//*:group[@nr=6])) then xs:integer($res//*:group[@nr=6]) else 0,
    'additional': tokenize($res//*:group[@nr=10], '&#x0a;'),
    'analyze-string': serialize($res)
  }    
};

declare function local:forwarded-problem($forwarded-problem as element()+) as map(*) {
  map {
      'code': 'local:forwarded',
      'description': '',
      'value': $forwarded-problem,
      'line-number': 0,
      'column-number': 0,
      'additional': ''
  }  
};

declare function local:empty-is-probably-401() as map(*) {
  map {
      'code': 'response-codes:_401',
      'description': $api-problem:codes_to_message(401),
      'value': request:get-attribute('api-problem.requested-filename')||' Most probably 401. exist-db does not provide any data if this is the error',
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
                        <li>analyze-string: {$parsed('analyze-string')}</li>
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
 : Additionally any xml returned from the first invocation is reparsed in a strange way setting lots of prefixes
 : if any (html, rfc7807) are defined in this file.
 : 401 responses from exist-db due to insufficient access rights set in the database don't forward any message
 : whatsoever. So guessing this situation this is also processed here into a respective rfc7807:problem
 : and then the actual rendering with correct headers is done in a second invocation.
 :)
if (((exists(request:get-attribute('org.exist.forward.error')) and
      exists(request:get-attribute('api-problem.set-status-code.workaround')))
     or (empty(request:get-attribute('org.exist.forward.error')) and empty(request:get-attribute('javax.servlet.error.message')))
     or (request:get-attribute('javax.servlet.error.status_code') instance of xs:integer and
      request:get-attribute('javax.servlet.error.status_code') = (404) and
      exists(request:get-attribute('api-problem.set-status-code.workaround')))
     ) and
    not(exists(request:get-attribute('api-problem.set-status-code.workaround.respond')))) then
    let $respond-in-next-invocation := request:set-attribute('api-problem.set-status-code.workaround.respond', 'true')
    return (
(:        console:log("respond creating rfc7807"), :)
        local:respond('application/restxq+xml')
    )
else
    try {(
(:        console:log("respond creating final rendering"),:)
(:        console:log(string-join(for $n in request:attribute-names() return $n||': '||request:get-attribute($n), '&#x0a;')),:)
        local:respond(request:get-header('Accept'))
    )}
    catch java:org.exist.xquery.XPathException | err:FODC0006 { (::)
        try {(
(:            console:log("respond can't process in respond org.exist.forward.error "||'&#x0a;':)
(:            ||$err:code||' at '||$err:module||':'||$err:line-number||':'||$err:column-number||'&#x0a;':)
(:            ||string-join($exerr:xquery-stack-trace, '&#x0a;'):)
(:            ||string-join($exerr:java-stack-trace, '&#x0a;'):)
(:            ||request:get-attribute('org.exist.forward.error'):)
(:            ), :)
            parse-xml-fragment(request:get-attribute('org.exist.forward.error'))
        )} catch err:FODC0006 {(
(:            console:log("org.exist.forward.error is no xml"), :)
            request:get-attribute('org.exist.forward.error')
        )}
    }