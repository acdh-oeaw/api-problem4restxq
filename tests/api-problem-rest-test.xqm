xquery version "3.0";

module namespace _ = "https://tools.ietf.org/html/rfc7807/tests";
import module namespace api-problem = "https://tools.ietf.org/html/rfc7807" at "../api-problem/api-problem.xqm";
import module namespace test-call-stack = "https://tools.ietf.org/html/rfc7807/test-call-stack" at "test-call-stack.xqm";
import module namespace test-errors = "https://tools.ietf.org/html/rfc7807/test-errors" at "test-errors.xqm";
import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace req = "http://exquery.org/ns/request";

declare namespace response-codes = "https://tools.ietf.org/html/rfc7231#section-6";

declare
  %rest:path('api-problem-tests/test1')
  %rest:GET
function _:test1() {
  api-problem:or_result(prof:current-ns(), _:error-out#3, [' Test1', ' Test2', ' Test3'])
};

declare %private function _:stack_l1($param1, $param2, $param3) {
    _:stack_l2($param1, $param2, $param3)
};

declare %private function _:stack_l2($param1, $param2, $param3) {
    _:stack_l3($param1, $param2, $param3)
};

declare %private function _:stack_l3($param1, $param2, $param3) {
    _:error-out($param1, $param2, $param3)
};

declare %private function _:error-out($param1, $param2, $param3) {
    error( xs:QName('_:an-error'), 'testError'||$param1||$param2||$param3, <test><_>{$param1}</_><_>{$param2}</_><_>{$param3}</_></test>)
};

declare
  %rest:path('api-problem-tests/test2')
  %rest:GET
function _:test2() {
   api-problem:or_result(prof:current-ns(), _:create-test-data#3, [' Test1', ' Test2', ' Test3'])
};

declare %private function _:create-test-data($param1, $param2, $param3) {
  switch(true())
  case (matches(req:header('accept'), '[+/]html')) return
  <html>
    <head>
      <title>Test OK!</title>
    </head>
    <body>
      <h1>Test OK!</h1>
      {$param1||$param2||$param3}
    </body>
  </html>
  case (matches(req:header('accept'), '[+/]json')) return
  map{"message": "Test OK!", 'param1': $param1, 'param2': $param2, 'param3': $param3}
  case (matches(req:header('accept'), '[+/]xml')) return
  <response><message>Test OK!</message><param1>{$param1}</param1><param2>{$param2}</param2><param3>{$param3}</param3></response>
  default return ``[Test OK! `{$param1}``{$param2}``{$param3}`]``
};

declare
  %rest:path('api-problem-tests/test3')
  %rest:GET
function _:test3() {
  api-problem:or_result(prof:current-ns(), _:custom-api-problem#0, [])
};

declare %private function _:custom-api-problem() {
  <problem xmlns="urn:ietf:rfc:7807">
     <type>https://example.com/probs/out-of-credit</type>
     <title>You do not have enough credit.</title>
     <detail>Your current balance is 30, but that costs 50.</detail>
     <instance>https://example.net/account/12345/msgs/abc</instance>
     <balance>30</balance>
     <status>402</status>
     <accounts>
       <_>https://example.net/account/12345</_>
       <_>https://example.net/account/67890</_>
     </accounts>
   </problem>
};

declare
  %rest:path('api-problem-tests/test4')
  %rest:GET
function _:test4() {
  api-problem:or_result(prof:current-ns(), _:standard-http-error#0, [])
};

declare %private function _:standard-http-error() {
   error(xs:QName('response-codes:_403'), 'Test access denied!', 'This is wrapped!')
};

declare
  %rest:path('api-problem-tests/test5')
  %rest:GET
function _:test5() {
    error(xs:QName('response-codes:_403'), 'Test access denied!', 'This is not wrapped!')
};

declare
  %rest:path('api-problem-tests/test6')
  %rest:GET
function _:test6() {
    test-call-stack:stack-int_l1()
};

declare
  %rest:GET
  %rest:path('api-problem-tests/test7')
function _:test7() {
  api-problem:or_result(prof:current-ns(), _:_test7#0, [])
};

declare %private function _:_test7() {
    test-call-stack:stack_l1(' Test1', ' Test2', ' Test3')
};

declare
  %rest:GET
  %rest:path('api-problem-tests/test8')
function _:test8() {
  api-problem:or_result(prof:current-ns(), _:_test8#0, [])
};

declare %private function _:_test8() {
    test-call-stack:catch-and-error()
};

declare
  %rest:GET
  %rest:path('api-problem-tests/test9')
function _:test9() {
  api-problem:or_result(prof:current-ns(), _:_test9#0, [])
};

declare %private function _:_test9() {
    test-errors:redirect_error("test2")
};

(: serve the test page :)

declare function _:get-base-uri-public() as xs:string {
    let $forwarded-hostname := if (contains(request:header('X-Forwarded-Host'), ',')) 
                                 then substring-before(request:header('X-Forwarded-Host'), ',')
                                 else request:header('X-Forwarded-Host'),
        $urlScheme := if ((lower-case(request:header('X-Forwarded-Proto')) = 'https') or 
                          (lower-case(request:header('Front-End-Https')) = 'on')) then 'https' else 'http',
        $port := if ($urlScheme eq 'http' and request:port() ne 80) then ':'||request:port()
                 else if ($urlScheme eq 'https' and not(request:port() eq 80 or request:port() eq 443)) then ':'||request:port()
                 else '',
        (: FIXME: this is to naive. Works for ProxyPass / to /exist/apps/cr-xq-mets/project
           but probably not for /x/y/z/ to /exist/apps/cr-xq-mets/project. Especially check the get module. :)
        $xForwardBasedPath := (request:header('X-Forwarded-Request-Uri'), request:path())[1]
    return $urlScheme||'://'||($forwarded-hostname, request:hostname())[1]||$port||$xForwardBasedPath
};

(:~
 : Returns a html or related file.
 : @param  $file  file or unknown path
 : @return rest response and binary file
 :)
declare
  %rest:path("api-problem-tests/{$file=[^/]+}")
function _:file($file as xs:string) as item()+ {
  let $path := _:base-dir()||$file
  return if (file:exists($path)) then
    if (matches($file, '\.(htm|html|js|map|css|png|gif|jpg|jpeg|ico|woff|woff2|ttf)$', 'i')) then
    _:return-content(file:read-binary($path), web:content-type($path)) else _:forbidden-file($file)
  else
    api-problem:return_problem(prof:current-ns(),
      <problem xmlns="urn:ietf:rfc:7807">
        <title>{$api-problem:codes_to_message(404)}</title>
        <detail>File {$file} not found</detail>
        <status>404</status>
      </problem>, ())
};

declare %private function _:return-content($bin, $media-type as xs:string) {
  let $hash := xs:string(xs:hexBinary(hash:md5($bin)))
       , $hashBrowser := request:header('If-None-Match', '')
    return if ($hash = $hashBrowser) then
      web:response-header(map{}, map{}, map{'status': 304, 'message': 'Not Modified'})
    else (
      web:response-header(map { 'media-type': $media-type,
                                'method': 'basex',
                                'binary': 'yes' }, 
                          map { 'X-UA-Compatible': 'IE=11'
                              , 'Cache-Control': 'max-age=3600,public'
                              , 'ETag': $hash }),
      $bin
    )
};

declare %private function _:base-dir() as xs:string {
  file:base-dir()
};

(:~
 : Returns index.html on /.
 : @param  $file  file or unknown path
 : @return rest response and binary file
 :)
declare
  %rest:path("api-problem-tests")
function _:index-file() as item()+ {
  let $index-html := _:base-dir()||'index.html',
      $uri := rest:uri(),
(:      $log := l:write-log('api:index-file() $uri := '||$uri||' base-uri-public := '||api:get-base-uri-public(), 'DEBUG'),:)
      $absolute-prefix := if (matches(_:get-base-uri-public(), '/$')) then () else _:get-base-uri-public()||'/'
  return if (exists($absolute-prefix)) then
    <rest:response>
      <http:response status="302">
        <http:header name="Location" value="{$absolute-prefix}"/>
      </http:response>
    </rest:response>
  else if (file:exists($index-html)) then
    <rest:forward>index.html</rest:forward>
  else _:forbidden-file($index-html)    
};

(:~
 : Return 403 on all other (forbidden files).
 : @param  $file  file or unknown path
 : @return rest response and binary file
 :)
declare
  %private
function _:forbidden-file($file as xs:string) as item()+ {
  <rest:response>
    <http:response status="403" message="{$file} forbidden.">
      <http:header name="Content-Language" value="en"/>
      <http:header name="Content-Type" value="text/html; charset=utf-8"/>
    </http:response>
  </rest:response>,
  <html xmlns="http://www.w3.org/1999/xhtml">
    <title>{$file||' forbidden'}</title>
    <body>        
       <h1>{$file||' forbidden'}</h1>
    </body>
  </html>
};

declare
  %rest:path("api-problem-tests/runtime")
function _:runtime-info() as item()+ {
  let $runtime-info := db:system(),
      $xslt-runtime-info := xslt:transform(<_/>,
      <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml"/><xsl:template match='/'><_><product-name><xsl:value-of select="system-property('xsl:product-name')"/></product-name><product-version><xsl:value-of select="system-property('xsl:product-version')"/></product-version></_></xsl:template></xsl:stylesheet>)/*
  return
  <html xmlns="http://www.w3.org/1999/xhtml">
    <title>Runtime info</title>
    <body>        
       <h1>Runtime info</h1>
       <table>
       {for $item in $runtime-info/*:generalinformation/*
       return
         <tr>
           <td>{$item/local-name()}</td>
           <td>{$item}</td>
         </tr>
       }
         <tr>
           <td>{$xslt-runtime-info/*:product-name/text()}</td>
           <td>{$xslt-runtime-info/*:product-version/text()}</td>
         </tr>
       </table>
    </body>
  </html>
};