xquery version "3.1";

module namespace _ = "https://tools.ietf.org/html/rfc7807/test-call-stack";
import module namespace m = "https://tools.ietf.org/html/rfc7807/test-errors" at "test-errors.xqm";
import module namespace api-problem = "https://tools.ietf.org/html/rfc7807" at "../api-problem.xqm";

declare function _:stack_l1($param1, $param2, $param3) {
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

declare function _:stack-int_l1() {
    _:stack-int_l2()
};

declare %private function _:stack-int_l2() {
    _:stack-int_l3()
};

declare %private function _:stack-int_l3() {
    m:error-out-int()
};

declare function _:catch-and-error() {
    try {
        _:stack-int_l1()
    } catch * {
        error(xs:QName('_:catch-and-error'), 'Catch and error', api-problem:pass($err:code, $err:description, $err:value, $exerr:xquery-stack-trace))
    }
};