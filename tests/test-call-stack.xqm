xquery version "3.1";

module namespace _ = "https://tools.ietf.org/html/rfc7807/test-call-stack";
import module namespace m = "https://tools.ietf.org/html/rfc7807/test-errors" at "test-errors.xqm";
import module namespace api-problem = "https://tools.ietf.org/html/rfc7807" at "../api-problem/api-problem.xqm";

(: all of the functions in this module would be inlined.
   As this is a demo for stack traces %basex:inline(0) is used excessivly:)

declare %basex:inline(0) function _:stack_l1($param1, $param2, $param3) {
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

declare %basex:inline(0) function _:stack-int_l1() {
    _:stack-int_l2()
};

declare %basex:inline(0) %private function _:stack-int_l2() {
    _:stack-int_l3()
};

declare %basex:inline(0) %private function _:stack-int_l3() {
    m:error-out-int()
};

declare %basex:inline(0) function _:catch-and-error() {
    try {
        _:stack-int_l1()
    } catch * {
        error(xs:QName('_:catch-and-error'), 'Catch and error', api-problem:pass($err:code, $err:description, $err:value, $err:additional))
    }
};