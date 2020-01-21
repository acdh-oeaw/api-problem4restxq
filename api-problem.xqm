xquery version "3.0";

module namespace _ = "https://tools.ietf.org/html/rfc7807";
import module namespace req = "http://exquery.org/ns/request";
import module namespace admin = "http://basex.org/modules/admin"; (: for logging :)

declare namespace rfc7807 = "urn:ietf:rfc:7807";
declare namespace response-codes = "https://tools.ietf.org/html/rfc7231#section-6";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";

declare variable $_:enable_trace external := true();

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
        return if ($ret instance of element(rfc7807:problem)) then _:return_problem($start-time-ns, $ret,$header-elements)
        else        
          (web:response-header(_:get_serialization_method($ret), $header-elements, map{'message': $_:codes_to_message($ok-status), 'status': $ok-status}),
          _:inject-runtime($start-time-ns, $ret)
          )
    } catch * {
        let $status-code := if (namespace-uri-from-QName($err:code) eq 'https://tools.ietf.org/html/rfc7231#section-6') then
          let $status-code-from-local-name := replace(local-name-from-QName($err:code), '_', '')
          return if ($status-code-from-local-name castable as xs:integer and 
                     xs:integer($status-code-from-local-name) > 400 and
                     xs:integer($status-code-from-local-name) < 511) then xs:integer($status-code-from-local-name) else 400
        else (500, admin:write-log($err:additional, 'ERROR'))
        return _:return_problem($start-time-ns,
                <problem xmlns="urn:ietf:rfc:7807">
                    <type>{namespace-uri-from-QName($err:code)}</type>
                    <title>{$err:description}</title>
                    <detail>{$err:value}</detail>
                    <instance>{namespace-uri-from-QName($err:code)}/{local-name-from-QName($err:code)}</instance>
                    <status>{$status-code}</status>
                    {if ($_:enable_trace) then <trace>{$err:module}: {$err:line-number}/{$err:column-number}{replace($err:additional, '^.*Stack Trace:', '', 's')}</trace> else ()}
                </problem>, $header-elements)     
    }
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

declare %private function _:inject-runtime($start as xs:integer, $ret) {
  if ($ret instance of map(*)) then map:merge($ret, map {'took': _:runtime($start)})
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
        let $start-time-ns := prof:current-ns(),
            $origin := try { req:header("Origin") } catch basex:http {'urn:local'},
            $status-code := 
          let $status-code-from-local-name := replace(local-name-from-QName(xs:QName($code)), '_', '')
          return if ($status-code-from-local-name castable as xs:integer and 
                     xs:integer($status-code-from-local-name) >= 400 and
                     xs:integer($status-code-from-local-name) < 511) then xs:integer($status-code-from-local-name) else
                     (500, admin:write-log($additional, 'ERROR'))
        return _:return_problem($start-time-ns,
                <problem xmlns="urn:ietf:rfc:7807">
                    <type>{namespace-uri-from-QName(xs:QName($code))}</type>
                    <title>{$description}</title>
                    <detail>{$value}</detail>
                    <instance>{namespace-uri-from-QName(xs:QName($code))}/{local-name-from-QName(xs:QName($code))}</instance>
                    <status>{$status-code}</status>
                    {if ($_:enable_trace) then <trace xml:space="preserve">{replace(replace($additional, '^.*Stopped at ', '', 's'), ':\n.*($|(\n\nStack Trace:(\n)))', '$3')}</trace> else ()}
                </problem>, if (exists($origin)) then map{"Access-Control-Allow-Origin": $origin,
                                "Access-Control-Allow-Credentials": "true"} else ())  
};

declare %private function _:on_accept_to_json($problem as element(rfc7807:problem)) {
  let $objects := string-join($problem//*[*[local-name() ne '_']]/local-name(), ' '),
      $arrays := string-join($problem//*[*[local-name() eq '_']]/local-name(), ' '),
      $accept-header := try { req:header("ACCEPT") } catch basex:http { 'application/problem+xml' }
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
};

declare function _:to-json-map($n as node(), $objects as xs:string*, $arrays as xs:string*) {
    let $objects := if (empty($objects)) then $n/descendant-or-self::*[*[local-name() ne '_']]/local-name() else $objects,
        $arrays := if (empty($arrays)) then $n/descendant-or-self::*[*[local-name() eq '_']]/local-name() else $arrays
  return if ($n/local-name() = '_') then array{for $arrayel in $n/(*|text()) return _:to-json-map($arrayel, $objects, $arrays)}
  else if ($n/text()) then map{_:convert-names-xml-json($n/local-name()): $n/text()}
  else if ($objects != "" and $n/local-name() = $objects)
  then map{_:convert-names-xml-json($n/local-name()): map:merge(for $subel in $n/* return _:to-json-map($subel, $objects, $arrays))}
  else if ($arrays != "" and $n/local-name() = $arrays)
  then map{_:convert-names-xml-json($n/local-name()): array{for $arrayel in $n/*:_/(*|text()) return _:to-json-map($arrayel, $objects, $arrays)}}
  else $n
};

declare function _:convert-names-xml-json($name as xs:string) {
    string-join(for $part in analyze-string('__0031title__', '__(\d\d\d\d)?')/* return
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