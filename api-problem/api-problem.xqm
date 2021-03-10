xquery version "3.0";

(: MIT License
 :
 : Copyright (c) 2020 Omar Siam ACDH-CH
 :
 : Permission is hereby granted, free of charge, to any person obtaining a copy
 : of this software and associated documentation files (the "Software"), to deal
 : in the Software without restriction, including without limitation the rights
 : to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 : copies of the Software, and to permit persons to whom the Software is
 : furnished to do so, subject to the following conditions:
 :
 : The above copyright notice and this permission notice shall be included in all
 : copies or substantial portions of the Software.
 :
 : THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 : IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 : FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 : AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 : LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 : OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 : SOFTWARE.
 :)

module namespace _ = "https://tools.ietf.org/html/rfc7807";
import module namespace req = "http://exquery.org/ns/request";
import module namespace admin = "http://basex.org/modules/admin"; (: for logging :)

declare namespace rfc7807 = "urn:ietf:rfc:7807";
declare namespace response-codes = "https://tools.ietf.org/html/rfc7231#section-6";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";

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
(: If you want (or are required to) supply additional information as headers add a map(xs:string, xs:string) using this key :)
declare variable $_:ADDITIONAL_HEADER_ELEMENTS := 'api-problem.additional-header-elements';
declare variable $_:API_PROBLEM_VALUE_KEYS := (
    $_:ADDITIONAL_STACK_TRACE, $_:ADDITIONAL_ERROR_CODES, $_:ADDITIONAL_DESCRIPTIONS, $_:ADDITIONAL_HEADER_ELEMENTS
);

declare function _:or_result($start-time-ns as xs:integer, $api-function as function(*)*, $parameters as array(*)) as item()+ {
    _:or_result($start-time-ns, $api-function, $parameters, (), ())
};

declare function _:or_result($start-time-ns as xs:integer, $api-function as function(*)*, $parameters as array(*), $header-elements as map(xs:string, xs:string)?) as item()+ {
    _:or_result($start-time-ns, $api-function, $parameters, (), $header-elements)
};

declare function _:or_result($start-time-ns as xs:integer, $api-function as function(*)*, $parameters as array(*), $ok-status as xs:integer?, $header-elements as map(xs:string, xs:string)?) as item()+ {
    try {
        let $ok-status := if ($ok-status > 200 and $ok-status < 300) then $ok-status else 200,
            $ret := apply($api-function, $parameters)
        return if ($ret instance of element(rfc7807:problem)) then _:return_problem($start-time-ns, $ret, $header-elements)
        else if ($ret[1] instance of element(rest:response)) then $ret
        else        
          (web:response-header(_:get_serialization_method($ret), $header-elements, map{'message': $_:codes_to_message($ok-status), 'status': $ok-status}),
          _:inject-runtime($start-time-ns, $ret)
          )
    } catch * {
        let $value-if-map := if ($err:value instance of map(*)) then $err:value else map {},            
            $additional := ((if ($err:value instance of map(*)) then $err:value($_:ADDITIONAL_STACK_TRACE) else ()), $err:additional)
        return _:problem-from-catch-vars($start-time-ns, $err:code, $err:description, $err:value, $err:module, $err:line-number, $err:column-number, $additional, try { req:header("ACCEPT") } catch basex:http { 'application/problem+xml' }, map:merge(($value-if-map($_:ADDITIONAL_HEADER_ELEMENTS), $header-elements)))
    }
};

declare %private function _:problem-from-catch-vars($start-time-ns as xs:integer, $code, $description, $value, $module, $line-number, $column-number, $additional as xs:string*, $accept as xs:string?, $header-elements as map(xs:string, xs:string)?) {
        let $codes := if ($value instance of map(*)) then ($value($_:ADDITIONAL_ERROR_CODES), $code) else $code,
            $descriptions := if ($value instance of map(*)) then ($value($_:ADDITIONAL_DESCRIPTIONS), $description) else $description,
            $additional := string-join($additional, '&#x0a;'),
            $status-code := if (namespace-uri-from-QName($codes[1]) eq 'https://tools.ietf.org/html/rfc7231#section-6') then
          let $status-code-from-local-name := replace(local-name-from-QName($code), '_', '')
          return if ($status-code-from-local-name castable as xs:integer and 
                     xs:integer($status-code-from-local-name) > 300 and
                     xs:integer($status-code-from-local-name) < 511) then xs:integer($status-code-from-local-name) else 400
        else (500, admin:write-log('Program error: returning 500'||'&#x0a;'||
                               namespace-uri-from-QName($codes[1])||':'||local-name-from-QName($codes[1])||'&#x0a;'||
                               string-join($descriptions, ' > ')||'&#x0a;'||$additional, 'ERROR'))
        return _:return_problem($start-time-ns,
                <problem xmlns="urn:ietf:rfc:7807">
                    <type>{namespace-uri-from-QName($codes[1])}</type>
                    <title>{string-join($codes, ' > ')}: {string-join($descriptions, ' > ')}</title>
                    <detail>{_:format_err_value($value)}</detail>
                    <instance>{_:code_to_instance_uri($codes[1])}</instance>
                    <status>{$status-code}</status>
                    {if ($_:enable_trace) then <trace>&#x0a;{$additional}</trace> else ()}
                </problem>, $header-elements)   
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
    then let $value := map:remove($value, $_:API_PROBLEM_VALUE_KEYS)
    return try { if (count(map:keys($value)) > 1 or ($value?* instance of map(*))) then serialize($value, map {'method': 'json'}) else $value?*}
    catch err:SERE0021 { serialize(map:merge(map:for-each($value, _:replace_functions#2)), map {'method': 'json'}) }
  else $value
  return _:xmlencode($plain-string)
};

declare %private function _:xmlencode($plain-string as xs:string?) as xs:string {
  if (exists($plain-string) and $plain-string != '')
  then $plain-string => replace('&amp;', '&amp;amp;') => replace('>', '&amp;gt;') => replace('<', '&amp;lt;')
  else ''
};

declare %private function _:replace_functions($key as xs:anyAtomicType, $value as item()*) {
    switch (true())
    case $value instance of map(*) return map {$key: map:merge(map:for-each($value, _:replace_functions#2))}
    case $value instance of function(*)* return map {$key: for $v in $value return try { _:render_function_as_string(inspect:function($v)) } catch * { 'function()' }}
    default return map {$key: $value}
};

declare %private function _:render_function_as_string($f as element(function)) as xs:string {
  let $module := if (exists($f/@module)) then data($f/@module)||': ' else '',
      $name := if (exists($f/@name)) then ' '||data($f/@name) else '',
      $annotations := if (exists($f/annotation)) then '%'||string-join($f/annotation/@name, ' %')||' ' else '',
      $args := if (exists($f/argument)) then '$'||string-join($f/argument!(data(./@name)||' as '||data(./@type)||data(./@occurrence)), ', $') else '', 
      $returns := if (exists($f/returns)) then ' as '||data($f/returns/@type)||data($f/returns/@occurrence) else ''
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

declare function _:return_problem($start-time-ns as xs:integer, $problem as element(rfc7807:problem), $header-elements as map(xs:string, xs:string)?) as item()+ {
let $accept-header := try { req:header("ACCEPT") } catch basex:http { 'application/problem+xml' },
    $header-elements := map:merge(($header-elements, map{'Content-Type': if (matches($accept-header, '[+/]json')) then 'application/problem+json' else if (matches($accept-header, 'application/xhtml\+xml')) then 'application/xml' else 'application/problem+xml'})),
    $error-status := if ($problem/rfc7807:status castable as xs:integer) then xs:integer($problem/rfc7807:status) else 400
return (web:response-header((), $header-elements, map{'message': $problem/rfc7807:title, 'status': $error-status}),
 _:on_accept_to_json($problem)
)   
};

declare function _:result($start-time-ns as xs:integer, $result as element(rfc7807:problem), $header-elements as map(xs:string, xs:string)?) {
  _:or_result($start-time-ns, _:return_result#1, [$result], $header-elements)
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

declare function _:pass($code as xs:QName, $description as xs:string?, $value as item()*, $additional as xs:string*) as map(*) {
    _:pass($code, $description, $value, $additional, ()) 
};

declare function _:pass($code as xs:QName, $description as xs:string?, $value as item()*, $additional as xs:string*, $java-stack-trace as xs:string*) as map(*) {
  if ($value instance of map(*)) then
      map:merge(($value,
      map {
            $_:ADDITIONAL_STACK_TRACE: ($value($_:ADDITIONAL_STACK_TRACE), $additional),
            $_:ADDITIONAL_ERROR_CODES: ($value($_:ADDITIONAL_ERROR_CODES), $code),
            $_:ADDITIONAL_DESCRIPTIONS: ($value($_:ADDITIONAL_DESCRIPTIONS), $description)
        }))
  else map {
            $_:ADDITIONAL_STACK_TRACE: $additional,
            $_:ADDITIONAL_ERROR_CODES: $code,
            $_:ADDITIONAL_DESCRIPTIONS: $description,
            '': $value
        }
};

declare %private function _:inject-runtime($start as xs:integer, $ret) {
  if ($ret instance of map(*)) then map:merge(($ret, map {'took': _:runtime($start)}))
  else if ($ret instance of element(json)) then $ret transform with { insert node <took>{_:runtime($start)}</took> as last into . }
  else $ret
};

declare %private function _:runtime($start as xs:integer) {
  ((prof:current-ns() - $start) idiv 10000) div 100
};

declare
(: use when there is another error handler :)
(:  %rest:error('Q{https://tools.ietf.org/html/rfc7231#section-6}*') :)
(: use when this is the only error handler :)
  %rest:error('*')
  %rest:error-param("code", "{$code}")
  %rest:error-param("description", "{$description}")
  %rest:error-param("value", "{$value}")
  %rest:error-param("module", "{$module}")
  %rest:error-param("line-number", "{$line-number}")
  %rest:error-param("column-number", "{$column-number}")
  %rest:error-param("additional", "{$additional}")
function _:error-handler($code as xs:string, $description, $value, $module, $line-number, $column-number, $additional) as item()+ {
    let $start-time := prof:current-ns(),
        $additional := ((if ($value instance of map(*)) then $value($_:ADDITIONAL_STACK_TRACE) else ()), $additional),
        $origin := try { req:header("Origin") } catch basex:http {'urn:local'},
        $value-if-map := if ($value instance of map(*)) then $value else map {},
        $header-elements := map:merge(($value-if-map($_:ADDITIONAL_HEADER_ELEMENTS), if (exists($origin)) then map{"Access-Control-Allow-Origin": $origin,
                                "Access-Control-Allow-Credentials": "true"} else ()))
    return if ($value instance of element()+ and $value[2] instance of element(rfc7807:problem)) 
    then _:return_problem($start-time, $value[2],  $header-elements)
    else try {
        let $code-as-QName := try { if ($code instance of xs:QName) then $code else xs:QName($code) } catch * { xs:QName('response-codes:_500') }
        return _:problem-from-catch-vars($start-time, $code-as-QName, $description, $value, $module, $line-number, $column-number, $additional, try { req:header("ACCEPT") } catch basex:http { 'application/problem+xml' }, $header-elements)
    } catch * {
        (admin:write-log('Error in error-handler: '||$err:code||' '||$err:description||' '||$additional, 'ERROR'),
        error(xs:QName('_:error-handler'), $err:code||' '||$err:description||' '||$additional))
    }
};

declare %private function _:on_accept_to_json($problem as element(rfc7807:problem)) {
  let $objects := string-join($problem//*[*[local-name() ne '_']]/local-name(), ' '),
      $arrays := string-join($problem//*[*[local-name() eq '_']]/local-name(), ' '),
      $accept-header := try { req:header("ACCEPT") } catch basex:http { 'application/problem+xml' }
  return
  if (matches($accept-header, '[+/]json'))
  (: BaseX native function: :)
  then json:serialize(<json type="object" objects="{$objects}" arrays="{$arrays}">{$problem/* transform with {delete node @xml:space}}</json>, map {'format': 'direct'})
  else $problem
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