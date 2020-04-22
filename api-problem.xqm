xquery version "3.1";

module namespace _ = "https://tools.ietf.org/html/rfc7807";
import module namespace req = "http://exquery.org/ns/request";
import module namespace console = "http://exist-db.org/xquery/console";
import module namespace insepct = "http://exist-db.org/xquery/inspection";
import module namespace util = "http://exist-db.org/xquery/util";

declare namespace rfc7807 = "urn:ietf:rfc:7807";
declare namespace response-codes = "https://tools.ietf.org/html/rfc7231#section-6";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare variable $_:enable_trace external := true();
(: A field in $model that contains the generated api-problem as XML. :)
declare variable $_:DATA := 'api-problem.data';
(: A field in $err:value if it is a map(*) that contains the stack trace
 : of caught nested errors as xs:string sequence. :)
declare variable $_:ADDITIONAL_STACK_TRACE := 'api-problem.additional-stack-trace';
(: A field in $err:value if it is a map(*) that contains the error codes
 : of caught nested errors as xs:string sequence. :)
declare variable $_:ADDITIONAL_ERROR_CODES := 'api-problem.error-codes';
(: A field in $err:value if it is a map(*) that contains the descriptions
 : of caught nested errors as xs:string sequence. :)
declare variable $_:ADDITIONAL_DESCRIPTIONS := 'api-problem.descriptions';
(: A field in $err:value if it is a map(*) that contains the java stack trace
 : of a caught nested error from java-bindings. :)
declare variable $_:JAVA_STACK_TRACE := 'api-problem.java-stack-trace';
(: If you want (or are required to) supply additional information as headers add a map(xs:string, xs:string) using this key :)
declare variable $_:ADDITIONAL_HEADER_ELEMENTS := 'api-problem.additional-header-elements';
declare variable $_:API_PROBLEM_VALUE_KEYS := (
    $_:ADDITIONAL_STACK_TRACE, $_:ADDITIONAL_ERROR_CODES, $_:ADDITIONAL_DESCRIPTIONS, $_:JAVA_STACK_TRACE, $_:ADDITIONAL_HEADER_ELEMENTS
);

declare function _:or_result($start-time as xs:time, $api-function as function(*)*, $parameters as array(*), $accept as xs:string?) as item()+ {
    _:or_result($start-time, $api-function, $parameters, $accept, (), ())
};

declare function _:or_result($start-time as xs:time, $api-function as function(*)*, $parameters as array(*), $accept as xs:string?, $header-elements as map(xs:string, xs:string)?) as item()+ {
    _:or_result($start-time, $api-function, $parameters, $accept, (), $header-elements)
};

declare function _:or_result($start-time as xs:time, $api-function as function(*)*, $parameters as array(*), $accept as xs:string?, $ok-status as xs:integer?, $header-elements as map(xs:string, xs:string)?) as item()+ {
    try {
        let $ok-status := if ($ok-status > 200 and $ok-status < 300) then $ok-status else 200,
            $ret := apply($api-function, $parameters)
        return if ($ret instance of element(rfc7807:problem)) then _:return_problem($start-time, $ret, $accept, $header-elements)
        else if ($ret[1] instance of element(rest:response)) then $ret
        else        
          (_:response-header(_:get_serialization_method($ret[1]), $header-elements, map{'message': $_:codes_to_message($ok-status), 'status': $ok-status}),
          _:inject-runtime($start-time, $ret)
          )
    } catch * {
        let $value-if-map := if ($err:value instance of map(*)) then $err:value else map {}
        return _:problem-from-catch-vars($start-time, $err:code, $err:description, $err:value, $err:module, $err:line-number, $err:column-number, $exerr:xquery-stack-trace, $exerr:java-stack-trace, $accept, map:merge(($value-if-map($_:ADDITIONAL_HEADER_ELEMENTS), $header-elements)))
    }
};

declare %private function _:problem-from-catch-vars($start-time as xs:time, $code, $description, $value, $module, $line-number, $column-number, $stack-trace, $java-stack-trace, $accept as xs:string, $header-elements as map(xs:string, xs:string)?) {
        let $fixed-stack := _:fix-stack($stack-trace, $value, $module, $line-number, $column-number),
            $codes := if ($value instance of map(*)) then ($value($_:ADDITIONAL_ERROR_CODES), $code) else $code,
            $java-stack-trace := if (namespace-uri-from-QName($codes[1]) = 'http://exist.sourceforge.net/NS/exist/java-binding')
               then '&#x0a;'||string-join(if ($value instance of map(*) and exists($value($_:JAVA_STACK_TRACE))) then $value($_:JAVA_STACK_TRACE) else $java-stack-trace, '&#x0a;') else '',
            $descriptions := if ($value instance of map(*)) then ($value($_:ADDITIONAL_DESCRIPTIONS), $description) else $description,
            $status-code := if (namespace-uri-from-QName($codes[1]) eq 'https://tools.ietf.org/html/rfc7231#section-6') then
          let $status-code-from-local-name := replace(local-name-from-QName($code), '_', '')
          return if ($status-code-from-local-name castable as xs:integer and 
                     xs:integer($status-code-from-local-name) > 300 and
                     xs:integer($status-code-from-local-name) < 511) then xs:integer($status-code-from-local-name) else 400
        else (500, _:write-log('Program error: returning 500'||'&#x0a;'||
                               namespace-uri-from-QName($codes[1])||':'||local-name-from-QName($codes[1])||'&#x0a;'||
                               string-join($descriptions, ' > ')||'&#x0a;'||$fixed-stack||$java-stack-trace, 'ERROR'))
        return _:return_problem($start-time,
                <problem xmlns="urn:ietf:rfc:7807">
                    <type>{namespace-uri-from-QName($codes[1])}</type>
                    <title>{string-join($codes, ' > ')}: {string-join($descriptions, ' > ')}</title>
                    <detail>{_:format_err_value($value)}</detail>
                    <instance>{_:code_to_instance_uri($codes[1])}</instance>
                    <status>{$status-code}</status>
                    {if ($_:enable_trace) then <trace>&#x0a;{$fixed-stack}{_:xmlencode($java-stack-trace)}</trace> else ()}
                </problem>, $accept, $header-elements)   
};

declare %private function _:code_to_instance_uri($code as xs:QName) as xs:string {
    if (exists($_:problem_qname_to_uri(xs:string($code)))) then $_:problem_qname_to_uri(xs:string($code))
    else
      let $ns-uri := namespace-uri-from-QName($code)
      return if ($ns-uri)
        then $ns-uri||(if (ends-with($ns-uri, '/')) then '' else '/')||local-name-from-QName($code)
        else xs:string($code)
};

declare %private function _:format_err_value($value) as xs:string {
  let $plain-string :=
  if ($value instance of map(*))
    then let $value := _:map_remove($value, $_:API_PROBLEM_VALUE_KEYS)
    return try { if (count(map:keys($value)) > 1 or ($value?* instance of map(*))) then serialize($value, map {'method': 'json'}) else $value?*}
    catch exerr:SENR0001 { serialize(map:merge(map:for-each($value, _:replace_functions#2)), map {'method': 'json'}) }
  else $value
  return _:xmlencode($plain-string)
};

declare %private function _:xmlencode($plain-string as xs:string) as xs:string {
  $plain-string => replace('&amp;', '&amp;amp;') => replace('>', '&amp;gt;') => replace('<', '&amp;lt;')  
};

(: workaround before 5.3: map:remove ignores second to n of sequence.
 : workaround in 4.3.1+: map:remove does not accept a sequence.
 :)
declare %private function _:map_remove($map as map(*), $keys-to-remove as xs:anyAtomicType*) {
    if (empty($keys-to-remove)) then $map
    else _:map_remove(map:remove($map, $keys-to-remove[1]), subsequence($keys-to-remove, 2))
};

declare %private function _:replace_functions($key as xs:anyAtomicType, $value as item()*) {
    switch (true())
    case $value instance of map(*) return map {$key: map:merge(map:for-each($value, _:replace_functions#2))}
    case $value instance of function(*)* return map {$key: for $v in $value return try { _:render_function_as_string(inspect:inspect-function($v)) } catch * { 'function()' }}
    default return map {$key: $value}
};

declare %private function _:render_function_as_string($f as element(function)) as xs:string {
  let $translate_cardinality := map {
    'exactly one': '',
    'zero or more': '*',
    'one or more': '+',
    'zero or one': '?'
  },
      $module := if (exists($f/@module)) then data($f/@module)||': ' else '',
      $name := if (exists($f/@name)) then ' '||data($f/@name) else '',
      $annotations := if (exists($f/annotation)) then '%'||string-join($f/annotation/@name, ' %')||' ' else '',
      $args := if (exists($f/argument)) then '$'||string-join($f/argument!(data(./@var)||' as '||data(./@type)||$translate_cardinality(data(./@cardinality))), ', $') else '', 
      $returns := if (exists($f/returns)) then ' as '||data($f/returns/@type)||$translate_cardinality(data($f/returns/@cardinality)) else ''
  return $annotations||'function'||$name||'('||$args||')'||$returns  
};

declare %private function _:get_serialization_method($ret as item()) as map(xs:string, xs:string) {
  switch(true())
  case ($ret instance of element(json)) return map {'method': 'json'}
  case ($ret instance of element() and $ret/local-name() = 'html') return map {'method': 'html'}
  case ($ret instance of element()) return map {'method': 'xml'}
  case ($ret instance of map(*)) return map {'method': 'json'}
  default return map {'method': 'text'}
};

declare function _:return_problem($start-time as xs:time, $problem as element(rfc7807:problem), $accept as xs:string?, $header-elements as map(xs:string, xs:string)?) as item()+ {
let $accept-header := try { req:header("ACCEPT") } catch exerr:* { if (exists($accept)) then $accept else 'application/json' },
    $header-elements := map:merge(($header-elements, map{'Content-Type': if (matches($accept-header, '[+/]json')) then 'application/problem+json' else if (matches($accept-header, 'application/xhtml\+xml')) then 'application/xml' else 'application/problem+xml'})),
(:    $log := console:log($header-elements),:)
    $error-status := if ($problem/rfc7807:status castable as xs:integer) then xs:integer($problem/rfc7807:status) else 400
return (_:response-header((), $header-elements, map{'message': $problem/rfc7807:title, 'status': $error-status}),
 _:inject-runtime($start-time, _:on_accept_to_json($problem, $accept))
)   
};

declare function _:result($start-time as xs:time, $result as element(rfc7807:problem), $accept as xs:string?, $header-elements as map(xs:string, xs:string)?) {
  _:or_result($start-time, _:return_result#1, [$result], $accept, $header-elements)
};

declare %private function _:return_result($to_return as node()) {
  $to_return
};

(: to be called from a catch * block like:
 : error(xs:QName('err:error-again'),
 :   'Catch and error',
 :   map:merge(
 :    (map{'additional': 'data'},
 :     api-problem:pass($err:code, $err:description, $err:value, $exerr:xquery-stack-trace))
 :   )
 : )
 :)

declare function _:pass($code as xs:QName, $description as xs:string?, $value as item()*, $stack-trace as xs:string*) as map(*) {
    _:pass($code, $description, $value, $stack-trace, ()) 
};

declare function _:pass($code as xs:QName, $description as xs:string?, $value as item()*, $stack-trace as xs:string*, $java-stack-trace as xs:string*) as map(*) {
  if ($value instance of map(*)) then
      map:merge(($value,
      map {
            $_:ADDITIONAL_STACK_TRACE: ($value($_:ADDITIONAL_STACK_TRACE), $stack-trace),
            $_:ADDITIONAL_ERROR_CODES: ($value($_:ADDITIONAL_ERROR_CODES), $code),
            $_:ADDITIONAL_DESCRIPTIONS: ($value($_:ADDITIONAL_DESCRIPTIONS), $description)
        },
      if (namespace-uri-from-QName($code) = 'http://exist.sourceforge.net/NS/exist/java-binding')
      then map { $_:JAVA_STACK_TRACE: $java-stack-trace } else ()))
  else map:merge((map {
            $_:ADDITIONAL_STACK_TRACE: $stack-trace,
            $_:ADDITIONAL_ERROR_CODES: $code,
            $_:ADDITIONAL_DESCRIPTIONS: $description,
            '': $value
        },
      if (namespace-uri-from-QName($code) = 'http://exist.sourceforge.net/NS/exist/java-binding')
      then map { $_:JAVA_STACK_TRACE: $java-stack-trace } else ()))
};

declare %private function _:inject-runtime($start as xs:time, $ret) {
  if ($ret instance of map(*)) then map:merge(($ret, map {'took': _:runtime($start)}))
  else if ($ret instance of element(json) and not($ret/*:took)) then <json>{($ret/(@*, *), <took>{_:runtime($start)}</took>)}</json>
  else if ($ret instance of element(rfc7807:problem) and not($ret/*:took)) then <problem xmlns="urn:ietf:rfc:7807">{($ret/(@*, *), <took>{_:runtime($start)}</took>)}</problem>
  else $ret
};

declare function _:runtime($start as xs:time) {
    let $diff as xs:dayTimeDuration := util:system-time() - $start
    return
        (hours-from-duration($diff) * 60 * 60 +
        minutes-from-duration($diff) * 60 +
        seconds-from-duration($diff)) * 1000
};

declare
(: In BaseX there is an annotation to install a catch all error handler.
 : In exist-db you can add /db/apps/api-problem/catch-all-handler.xql as a 
 : handler for every (!) uncaught error in web.xml
 : Add
 : <error-page>
 :     <location>/rest/db/apps/api-problem/catch-all-handler.xql</location>
 : </error-page>
 : After that you need to restart.
 : If you don't want to do that remember to always split RestXQ functions in two
 : and use a minimal caller to the actual function with the %rest annotations
 : function _:example($accept as xs:string*) {
 :   api-problem:or_result(util:system-time(), _:actual#0, [], string-join($accept, ','))
 : };
 : If you want to use this in a view.xql and get additional information in detail see the
 : examples provided in view-with-catch.xql
 :)
function _:error-handler($code, $description as xs:string?, $value, $module as xs:string?, $line-number as xs:integer?, $column-number as xs:integer?, $stack-trace as xs:string*, $java-stack-trace as xs:string*, $accept, $origin) {
    let $start-time := util:system-time(),
        $origin := $origin,
        $value-if-map := if ($value instance of map(*)) then $value else map {},
        $header-elements := map:merge(($value-if-map($_:ADDITIONAL_HEADER_ELEMENTS), if (exists($origin)) then map{"Access-Control-Allow-Origin": $origin,
                                "Access-Control-Allow-Credentials": "true"} else ()))
    return if ($value instance of element()+ and $value[2] instance of element(rfc7807:problem)) 
    then _:return_problem($start-time, $value[2], $accept, $header-elements)
    else try {
        let $code-as-QName := try { if ($code instance of xs:QName) then $code else xs:QName($code) } catch * { xs:QName('response-codes:_500') }
        return _:problem-from-catch-vars($start-time, $code-as-QName, $description, $value, $module, $line-number, $column-number, $stack-trace, $java-stack-trace, $accept, $header-elements)
    } catch * {
        let $fixed-stack := _:fix-stack($exerr:xquery-stack-trace, $err:value, $err:module, $err:line-number, $err:column-number)
        return (_:write-log('Error in error-handler: '||$err:code||' '||$err:description||' '||$fixed-stack, 'ERROR'),
        error(xs:QName('_:error-handler'), $err:code||' '||$err:description||' '||$fixed-stack))
    }
};

declare function _:fix-stack($raw-stack as xs:string*, $value, $module as xs:string?, $line-number as xs:integer?, $column-number as xs:integer?) as xs:string? {
  let $raw-stack := ((if ($value instance of map(*)) then $value($_:ADDITIONAL_STACK_TRACE) else ()), $raw-stack)
  return if (empty($raw-stack)) then '??? '||'['||$line-number||':'||$column-number||':'||$module||']'
  else let $trace-lines := (
        map {
            'line': $line-number,
            'column': $column-number
        },
        for $tl in $raw-stack
        let $parts := analyze-string($tl, '^(\s+|at )?([^\[]+)\[(-?\d+):(-?\d+):(.*)\]')
        where $parts//*:group[@nr=1]
        return map {
                'function': xs:string($parts//*:group[@nr=2]),
                'line': xs:integer($parts//*:group[@nr=3]),
                'column': xs:integer($parts//*:group[@nr=4]),
                'module': xs:string($parts//*:group[@nr=5])
            }
        ),
        $fixed-trace-lines := for $tl at $i in $trace-lines
        where $tl('line') >= 0
        return map{
                'function': if (exists($trace-lines[$i+1])) then $trace-lines[$i+1]('function') else '??? ',
                'line': $tl('line'),
                'column': $tl('column'),
                'module': if (exists($trace-lines[$i+1])) then $trace-lines[$i+1]('module') else $module
        }
    return string-join(for $tl in $fixed-trace-lines return $tl('function')||'['||$tl('line')||':'||$tl('column')||':'||$tl('module')||']'
    , '&#x0a;')
};

declare %private function _:on_accept_to_json($problem as element(rfc7807:problem), $accept as xs:string?) {
  let $objects := string-join($problem//*[*[local-name() ne '_']]/local-name(), ' '),
      $arrays := string-join($problem//*[*[local-name() eq '_']]/local-name(), ' '),
      $accept-header := try { if (req:header("ACCEPT") = '') then req:header("ACCEPT") else 'application/problem+xml' }
                        catch exerr:* { if (exists($accept)) then $accept else 'application/problem+xml' }
  return
  if (matches($accept-header, '[+/]json'))
  then _:to-json-map(<json type="object" objects="{$objects}" arrays="{$arrays}">{$problem/*}</json>)
  (: BaseX native function: :)
  (: json:serialize(<json type="object" objects="{$objects}" arrays="{$arrays}">{$problem/* transform with {delete node @xml:space}}</json>, map {'format': 'direct'}) :)
  else $problem
};

declare function _:to-json-map($json-xml as element(json)) {
    (: consistency checks: array -> <_>, object -> exists /*, () -> not exists /*,
       same for @objects and @ arrays,
       perhaps attributes? namespaces? :)
    let $objects := tokenize($json-xml/@objects, " "),
        $arrays := tokenize($json-xml/@arrays, " ")
    return if ($json-xml/@type = "object") then map:merge(for $subel in $json-xml/* return _:to-json-map($subel, $objects, $arrays))
    else if ($json-xml/@type = "array") then array{for $arrayel in $json-xml/*:_/(*|text()) return _:to-json-map($arrayel, $objects, $arrays)}
    else error(xs:QName("_:json-convert-error"), "Only root types array and json are implemented.")
(:    } catch * { $err:code||': '||$err:description||' '||serialize($json-xml, map {'method': 'xml', 'indent': true()}) }:)
};

declare function _:to-json-map($n as node(), $objects as xs:string*, $arrays as xs:string*) {
    let $objects := if (empty($objects)) then $n/descendant-or-self::*[*[local-name() ne '_']]/local-name() else $objects,
        $arrays := if (empty($arrays)) then $n/descendant-or-self::*[*[local-name() eq '_']]/local-name() else $arrays
  return if ($n/local-name() = '_') then array{for $arrayel in $n/(*|text()) return _:to-json-map($arrayel, $objects, $arrays)}
  else if ($n/text()) then map{_:convert-names-xml-json($n/local-name()): $n/text()}
  else if (not($n/*) and not($n instance of text())) then map{_:convert-names-xml-json($n/local-name()): ''}
  else if ($objects != "" and $n/local-name() = $objects)
  then map{_:convert-names-xml-json($n/local-name()): map:merge(for $subel in $n/* return _:to-json-map($subel, $objects, $arrays))}
  else if ($arrays != "" and $n/local-name() = $arrays)
  then map{_:convert-names-xml-json($n/local-name()): array{for $arrayel in $n/*:_/(*|text()) return _:to-json-map($arrayel, $objects, $arrays)}}
  else $n
};

declare function _:convert-names-xml-json($name as xs:string) {
    string-join(for $part in analyze-string($name, '__(\d\d\d\d)?')/* return
    if ($part instance of element(fn:non-match)) then $part/text()
    else if ($part instance of element(fn:match) and $part/fn:group) then codepoints-to-string(_:decode-hex-string($part/fn:group))
    else '_', '')
};

declare function _:decode-hex-string($val as xs:string)
  as xs:integer
{
  _:decodeHexStringHelper(string-to-codepoints($val), 0)
};

declare %private function _:decodeHexChar($val as xs:integer)
  as xs:integer
{
  let $tmp := $val - 48 (: '0' :)
  let $tmp := if($tmp <= 9) then $tmp else $tmp - (65-48) (: 'A'-'0' :)
  let $tmp := if($tmp <= 15) then $tmp else $tmp - (97-65) (: 'a'-'A' :)
  return $tmp
};

declare %private function _:decodeHexStringHelper($chars as xs:integer*, $acc as xs:integer)
  as xs:integer
{
  if(empty($chars)) then $acc
  else _:decodeHexStringHelper(remove($chars,1), ($acc * 16) + _:decodeHexChar($chars[1]))
};

declare %private function _:write-log($message as xs:string, $loglevel as xs:string) as empty-sequence() {
  let $log := (console:log($loglevel, $message),
    util:log($loglevel, $message),
    util:log-system-err($message))
  return ()
};

declare function _:response-header($output as map(*)?, $headers as map(*)?, $atts as map(*)?) as element(rest:response) {
let $output := map:merge(if (exists($headers) and contains($headers('Content-Type'), 'json')) then map{'method': 'json'} else ($output))
return <rest:response xmlns:rest="http://exquery.org/ns/restxq">
  <http:response xmlns:http="http://expath.org/ns/http-client">
    {if (exists($atts)) then for $k in map:keys($atts) return attribute {$k} {$atts($k)} else ()}
    {if (exists($headers)) then for $k in map:keys($headers) return <http:header name="{$k}" value="{$headers($k)}"/> else ()}
  </http:response>
  <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
    {if (exists($output)) then for $k in map:keys($output) return element {xs:QName('output:'||$k)} {namespace {'output'} {'http://www.w3.org/2010/xslt-xquery-serialization'}, attribute {'value'} {$output($k)} } else ()} 
  </output:serialization-parameters>
</rest:response>
};

declare function _:set-status-and-headers-like-restxq($restxq-header as element()) as empty-sequence() {
    (response:set-status-code($restxq-header/http:response/@status),
     for $header in $restxq-header/http:response/http:header[not(@name=('Content-Type'))] return response:set-header($header/@name, $header/@value))
};

declare function _:render-output-according-to-accept($accept as xs:string, $template, $api-problem-restxq as item()+, $render-function as function(element(), element(rfc7807:problem)) as item()* ) as item()* {
    let $template := if ($template instance of document-node()) then $template/* else $template,
        $should-render := (
          $template instance of element() and $template/namespace-uri() = 'http://www.w3.org/1999/xhtml' and
          matches($accept, 'application/xhtml\+xml'))
(:      , $log := console:log($api-problem[1]):)
    return switch (true())
          case $api-problem-restxq[1]/output:serialization-parameters/output:method/@value/data() = 'json' return serialize($api-problem-restxq[2], map{'method': 'json'})
          case $should-render return (response:set-header('Content-Type', 'text/html'), $render-function($template, $api-problem-restxq[2]))
          default return $api-problem-restxq[2]
};

declare function _:get-stream-serialization-options($output, $api-problem-restxq) as xs:string {
    let $is-html := $output instance of element() and $output/namespace-uri() = 'http://www.w3.org/1999/xhtml',
        $serialization-options := switch (true())
          case $api-problem-restxq[1]/output:serialization-parameters/output:method/@value/data() = 'json' return 'method=text'
          case $is-html return 'method=xhtml'
          default return string-join(for $param in $api-problem-restxq[1]/output:serialization-parameters/* return concat($param/local-name(), '=', $param/@value), ' ')
        return if ($is-html)
          then $serialization-options||' media-type=text/html'
          else $serialization-options||' media-type='||$api-problem-restxq[1]/hc:response/hc:header[@name='Content-Type']/@value
};

declare function _:as_html_pre($node as node(), $model as map(*)) {
  <pre xmlns="http://www.w3.org/1999/xhtml">{($node/@*, serialize($model($_:DATA), map{'indent': true()}))}</pre>  
};

declare function _:trace_as_pre($node as node(), $model as map(*)) {
  <pre xmlns="http://www.w3.org/1999/xhtml">{($node/@*, $model($_:DATA)/rfc7807:trace/text())}</pre>  
};

declare function _:type($node as node(), $model as map(*)) {
  $model($_:DATA)/rfc7807:type/text()
};

declare function _:type_as_link($node as node(), $model as map(*), $link-text as xs:string) {
  <a href="{$model($_:DATA)/rfc7807:type}">{$node/@target}{$link-text}</a>
};

declare function _:instance($node as node(), $model as map(*)) {
  $model($_:DATA)/rfc7807:instance/text()
};

declare function _:instance_as_link($node as node(), $model as map(*), $link-text as xs:string) {
  <a href="{$model($_:DATA)/rfc7807:instance}">{($node/@*, $link-text)}</a>
};

declare function _:title($node as node(), $model as map(*)) {
  $model($_:DATA)/rfc7807:title/text()
};

declare function _:detail($node as node(), $model as map(*)) {
  $model($_:DATA)/rfc7807:detail/text()
};

declare function _:detail-to-ul($node as node(), $model as map(*)) {
  try {
    if (exists($model($_:DATA)/rfc7807:detail/text()))
    then _:map-to-ul(parse-json($model($_:DATA)/rfc7807:detail/text()))
    else ()  
  } catch err:FOJS0001 { $model($_:DATA)/rfc7807:title/text() }
};

declare %private function _:map-to-ul($map as map(*)) {
  <ul xmlns="http://www.w3.org/1999/xhtml" class="api-problem detail level">
    {for $k in map:keys($map)
     where exists($map($k))
     return <li><span class="api-problem detail key">{$k}</span>
                <span class="api-problem detail value">{
                      if ($map($k) instance of map(*)) 
                      then  _:map-to-ul($map($k))
                      else $map($k)}
                </span>
            </li>
    }
  </ul>
};

declare function _:detail_or_explain($node as node(), $model as map(*)) {
  if ($model($_:DATA)/rfc7807:detail/text()) then $model($_:DATA)/rfc7807:detail/text()
  else 'If the error was caught by an error-handler or error-page configuration then there are no details available, sorry.'
};

declare function _:status($node as node(), $model as map(*)) {
  $model($_:DATA)/rfc7807:status/text()
};

declare variable $_:codes_to_message := map {
    100: 'Continue',
    101: 'Switching Protocols',
    102: 'Processing',

    200: 'OK',
    201: 'Created',
    202: 'Accepted',
    203: 'Non-Authoritative Information',
    204: 'No Content',
    205: 'Reset Content',
    206: 'Partial Content',
    207: 'Multi-Status',
    208: 'Already Reported',
    226: 'IM Used',

    300: 'Multiple Choices',
    301: 'Moved Permanently',
    302: 'Moved Temporarily',
    303: 'See Other',
    304: 'Not Modified',
    305: 'Use Proxy',
    306: 'Switch Proxy',
    307: 'Temporary Redirect',
    308: 'Permanent Redirect',

    400: 'Bad Request',
    401: 'Unauthorized',
    402: 'Payment Required',
    403: 'Forbidden',
    404: 'Not Found',
    405: 'Method Not Allowed',
    406: 'Not Acceptable',
    407: 'Proxy Authentication Required',
    408: 'Request Time-out',
    409: 'Conflict',
    410: 'Gone',
    411: 'Length Required',
    412: 'Precondition Failed',
    413: 'Request Entity Too Large',
    414: 'URI Too Long',
    415: 'Unsupported Media Type',
    416: 'Requested range not satisfiable',
    417: 'Expectation Failed',
    418: 'I’m a teapot',
    420: 'Policy Not Fulfilled',
    421: 'Misdirected Request',
    422: 'Unprocessable Entity',
    423: 'Locked',
    424: 'Failed Dependency',
    425: 'Unordered Collection',
    426: 'Upgrade Required',
    428: 'Precondition Required',
    429: 'Too Many Requests',
    431: 'Request Header Fields Too Large',
    444: 'No Response',
    449: 'Retry',
    451: 'Unavailable For Legal Reasons',
    499: 'Client Closed Request',

    500: 'Internal Server Error',
    501: 'Not Implemented',
    502: 'Bad Gateway',
    503: 'Service Unavailable',
    504: 'Gateway Time-out',
    505: 'HTTP Version not supported',
    506: 'Variant Also Negotiates',
    507: 'Insufficient Storage',
    508: 'Loop Detected',
    509: 'Bandwidth Limit Exceeded',
    510: 'Not Extended',
    511: 'Network Authentication Required'
};

(:  <instance> - A URI reference that identifies the specific
      occurrence of the problem.  It may or may not yield further
      information if dereferenced. :)
      
declare variable $_:problem_qname_to_uri := map {
(: from https://tools.ietf.org/html/rfc7231#section-6.1 :)
    'response-codes:_100': 'https://tools.ietf.org/html/rfc7231#section-6.2.1',
    'response-codes:_101': 'https://tools.ietf.org/html/rfc7231#section-6.2.2',
    'response-codes:_200': 'https://tools.ietf.org/html/rfc7231#section-6.3.1',
    'response-codes:_201': 'https://tools.ietf.org/html/rfc7231#section-6.3.2',
    'response-codes:_202': 'https://tools.ietf.org/html/rfc7231#section-6.3.3',
    'response-codes:_203': 'https://tools.ietf.org/html/rfc7231#section-6.3.4',
    'response-codes:_204': 'https://tools.ietf.org/html/rfc7231#section-6.3.5',
    'response-codes:_205': 'https://tools.ietf.org/html/rfc7231#section-6.3.6',
    'response-codes:_206': 'https://tools.ietf.org/html/rfc7233#section-4.1',
    'response-codes:_300': 'https://tools.ietf.org/html/rfc7231#section-6.4.1',
    'response-codes:_301': 'https://tools.ietf.org/html/rfc7231#section-6.4.2',
    'response-codes:_302': 'https://tools.ietf.org/html/rfc7231#section-6.4.3',
    'response-codes:_303': 'https://tools.ietf.org/html/rfc7231#section-6.4.4',
    'response-codes:_304': 'https://tools.ietf.org/html/rfc7232#section-4.1',
    'response-codes:_305': 'https://tools.ietf.org/html/rfc7231#section-6.4.5',
    'response-codes:_307': 'https://tools.ietf.org/html/rfc7231#section-6.4.7',
    'response-codes:_400': 'https://tools.ietf.org/html/rfc7231#section-6.5.1',
    'response-codes:_401': 'https://tools.ietf.org/html/rfc7235#section-3.1',
    'response-codes:_402': 'https://tools.ietf.org/html/rfc7231#section-6.5.2',
    'response-codes:_403': 'https://tools.ietf.org/html/rfc7231#section-6.5.3',
    'response-codes:_404': 'https://tools.ietf.org/html/rfc7231#section-6.5.4',
    'response-codes:_405': 'https://tools.ietf.org/html/rfc7231#section-6.5.5',
    'response-codes:_406': 'https://tools.ietf.org/html/rfc7231#section-6.5.6',
    'response-codes:_407': 'https://tools.ietf.org/html/rfc7235#section-3.2',
    'response-codes:_408': 'https://tools.ietf.org/html/rfc7231#section-6.5.7',
    'response-codes:_409': 'https://tools.ietf.org/html/rfc7231#section-6.5.8',
    'response-codes:_410': 'https://tools.ietf.org/html/rfc7231#section-6.5.9',
    'response-codes:_411': 'https://tools.ietf.org/html/rfc7231#section-6.5.10',
    'response-codes:_412': 'https://tools.ietf.org/html/rfc7232#section-4.2',
    'response-codes:_413': 'https://tools.ietf.org/html/rfc7231#section-6.5.11',
    'response-codes:_414': 'https://tools.ietf.org/html/rfc7231#section-6.5.12',
    'response-codes:_415': 'https://tools.ietf.org/html/rfc7231#section-6.5.13',
    'response-codes:_416': 'https://tools.ietf.org/html/rfc7233#section-4.4',
    'response-codes:_417': 'https://tools.ietf.org/html/rfc7231#section-6.5.14',
    'response-codes:_426': 'https://tools.ietf.org/html/rfc7231#section-6.5.15',
    'response-codes:_500': 'https://tools.ietf.org/html/rfc7231#section-6.6.1',
    'response-codes:_501': 'https://tools.ietf.org/html/rfc7231#section-6.6.2',
    'response-codes:_502': 'https://tools.ietf.org/html/rfc7231#section-6.6.3',
    'response-codes:_503': 'https://tools.ietf.org/html/rfc7231#section-6.6.4',
    'response-codes:_504': 'https://tools.ietf.org/html/rfc7231#section-6.6.5',
    'response-codes:_505': 'https://tools.ietf.org/html/rfc7231#section-6.6.6',
(:  from https://www.w3.org/TR/xpath-functions-31 :)
    'err:FOAP0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFOAP0001',
    'err:FOAR0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFOAR0001',
    'err:FOAR0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFOAR0002',
    'err:FOAY0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFOAY0001',
    'err:FOAY0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFOAY0002',
    'err:FOCA0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCA0001',
    'err:FOCA0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCA0002',
    'err:FOCA0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCA0003',
    'err:FOCA0005':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCA0005',
    'err:FOCA0006':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCA0006',
    'err:FOCH0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCH0001',
    'err:FOCH0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCH0002',
    'err:FOCH0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCH0003',
    'err:FOCH0004':'https://www.w3.org/TR/xpath-functions-31/#ERRFOCH0004',
    'err:FODC0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFODC0001',
    'err:FODC0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFODC0002',
    'err:FODC0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFODC0003',
    'err:FODC0004':'https://www.w3.org/TR/xpath-functions-31/#ERRFODC0004',
    'err:FODC0005':'https://www.w3.org/TR/xpath-functions-31/#ERRFODC0005',
    'err:FODC0006':'https://www.w3.org/TR/xpath-functions-31/#ERRFODC0006',
    'err:FODC0010':'https://www.w3.org/TR/xpath-functions-31/#ERRFODC0010',
    'err:FODF1280':'https://www.w3.org/TR/xpath-functions-31/#ERRFODF1280',
    'err:FODF1310':'https://www.w3.org/TR/xpath-functions-31/#ERRFODF1310',
    'err:FODT0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFODT0001',
    'err:FODT0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFODT0002',
    'err:FODT0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFODT0003',
    'err:FOER0000':'https://www.w3.org/TR/xpath-functions-31/#ERRFOER0000',
    'err:FOFD1340':'https://www.w3.org/TR/xpath-functions-31/#ERRFOFD1340',
    'err:FOFD1350':'https://www.w3.org/TR/xpath-functions-31/#ERRFOFD1350',
    'err:FOJS0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFOJS0001',
    'err:FOJS0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFOJS0003',
    'err:FOJS0004':'https://www.w3.org/TR/xpath-functions-31/#ERRFOJS0004',
    'err:FOJS0005':'https://www.w3.org/TR/xpath-functions-31/#ERRFOJS0005',
    'err:FOJS0006':'https://www.w3.org/TR/xpath-functions-31/#ERRFOJS0006',
    'err:FOJS0007':'https://www.w3.org/TR/xpath-functions-31/#ERRFOJS0007',
    'err:FONS0004':'https://www.w3.org/TR/xpath-functions-31/#ERRFONS0004',
    'err:FONS0005':'https://www.w3.org/TR/xpath-functions-31/#ERRFONS0005',
    'err:FOQM0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFOQM0001',
    'err:FOQM0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFOQM0002',
    'err:FOQM0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFOQM0003',
    'err:FOQM0005':'https://www.w3.org/TR/xpath-functions-31/#ERRFOQM0005',
    'err:FOQM0006':'https://www.w3.org/TR/xpath-functions-31/#ERRFOQM0006',
    'err:FORG0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0001',
    'err:FORG0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0002',
    'err:FORG0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0003',
    'err:FORG0004':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0004',
    'err:FORG0005':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0005',
    'err:FORG0006':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0006',
    'err:FORG0008':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0008',
    'err:FORG0009':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0009',
    'err:FORG0010':'https://www.w3.org/TR/xpath-functions-31/#ERRFORG0010',
    'err:FORX0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFORX0001',
    'err:FORX0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFORX0002',
    'err:FORX0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFORX0003',
    'err:FORX0004':'https://www.w3.org/TR/xpath-functions-31/#ERRFORX0004',
    'err:FOTY0012':'https://www.w3.org/TR/xpath-functions-31/#ERRFOTY0012',
    'err:FOTY0013':'https://www.w3.org/TR/xpath-functions-31/#ERRFOTY0013',
    'err:FOTY0014':'https://www.w3.org/TR/xpath-functions-31/#ERRFOTY0014',
    'err:FOTY0015':'https://www.w3.org/TR/xpath-functions-31/#ERRFOTY0015',
    'err:FOUT1170':'https://www.w3.org/TR/xpath-functions-31/#ERRFOUT1170',
    'err:FOUT1190':'https://www.w3.org/TR/xpath-functions-31/#ERRFOUT1190',
    'err:FOUT1200':'https://www.w3.org/TR/xpath-functions-31/#ERRFOUT1200',
    'err:FOXT0001':'https://www.w3.org/TR/xpath-functions-31/#ERRFOXT0001',
    'err:FOXT0002':'https://www.w3.org/TR/xpath-functions-31/#ERRFOXT0002',
    'err:FOXT0003':'https://www.w3.org/TR/xpath-functions-31/#ERRFOXT0003',
    'err:FOXT0004':'https://www.w3.org/TR/xpath-functions-31/#ERRFOXT0004',
    'err:FOXT0006':'https://www.w3.org/TR/xpath-functions-31/#ERRFOXT0006'
};