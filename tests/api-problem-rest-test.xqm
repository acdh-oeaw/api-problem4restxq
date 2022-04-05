xquery version "3.0";

module namespace _ = "https://tools.ietf.org/html/rfc7807/tests";
import module namespace api-problem = "https://tools.ietf.org/html/rfc7807" at "../api-problem.xqm";
import module namespace test-call-stack = "https://tools.ietf.org/html/rfc7807/test-call-stack" at "test-call-stack.xqm";
import module namespace test-errors = "https://tools.ietf.org/html/rfc7807/test-errors" at "test-errors.xqm";
import module namespace rest = "http://exquery.org/ns/restxq";
import module namespace req = "http://exquery.org/ns/request";

declare namespace response-codes = "https://tools.ietf.org/html/rfc7231#section-6";

(: all of the functions in this module would be inlined.
   As this is a demo for stack traces %basex:inline(0) is used excessivly:)

declare
  %rest:path('tests/test1')
  %rest:GET
  %basex:inline(0)
function _:test1() {
  api-problem:render-output-according-to-accept (
    api-problem:or_result(prof:current-ns(), _:stack_l1#3, [' Test1', ' Test2', ' Test3'])
  )
};

declare %basex:inline(0) %private function _:stack_l1($param1, $param2, $param3) {
    _:stack_l2($param1, $param2, $param3)
};

declare %basex:inline(0) %private function _:stack_l2($param1, $param2, $param3) {
    _:stack_l3($param1, $param2, $param3)
};

declare %basex:inline(0) %private function _:stack_l3($param1, $param2, $param3) {
    _:error-out($param1, $param2, $param3)
};

declare %basex:inline(0) %private function _:error-out($param1, $param2, $param3) {
    error( xs:QName('_:an-error'), 'testError'||$param1||$param2||$param3, <test><_>{$param1}</_><_>{$param2}</_><_>{$param3}</_></test>)
};

declare
  %rest:path('tests/test2')
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
  %rest:path('tests/test3')
  %rest:GET
  %basex:inline(0)
function _:test3() {
  api-problem:or_result(prof:current-ns(), _:custom-api-problem#0, [])
};

declare %basex:inline(0) %private function _:custom-api-problem() {
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
  %rest:path('tests/test4')
  %rest:GET
  %basex:inline(0)
function _:test4() {
  api-problem:or_result(prof:current-ns(), _:standard-http-error#0, [])
};

declare %basex:inline(0) %private function _:standard-http-error() {
   error(xs:QName('response-codes:_403'), 'Test access denied!', 'This is wrapped!')
};

declare
  %rest:path('tests/test5')
  %rest:GET
  %basex:inline(0)
function _:test5() {
    error(xs:QName('response-codes:_403'), 'Test access denied!', 'This is not wrapped!')
};

declare
  %rest:path('tests/test6')
  %rest:GET
  %basex:inline(0)
function _:test6() {
    test-call-stack:stack-int_l1()
};

declare
  %rest:GET
  %rest:path('tests/test7')
  %basex:inline(0)
function _:test7() {
  api-problem:or_result(prof:current-ns(), _:_test7#0, [])
};

declare %basex:inline(0) %private function _:_test7() {
    test-call-stack:stack_l1(' Test1', ' Test2', ' Test3')
};

declare
  %rest:GET
  %rest:path('tests/test8')
  %basex:inline(0)
function _:test8() {
  api-problem:render-output-according-to-accept (
    api-problem:or_result(prof:current-ns(), _:_test8#0, [])
  )
};

declare %basex:inline(0) %private function _:_test8() {
    test-call-stack:catch-and-error()
};
declare
  %rest:GET
  %rest:path('tests/test9')
  %basex:inline(0)
function _:test9() {
  api-problem:or_result(prof:current-ns(), _:_test9#0, [])
};

declare %basex:inline(0) %private function _:_test9() {
    test-errors:redirect_error("test2")
};