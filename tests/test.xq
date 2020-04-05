xquery version "3.1";

import module namespace web = "https://tools.ietf.org/html/rfc7807" at '../api-problem.xqm';
import module namespace t = "https://tools.ietf.org/html/rfc7807/tests" at 'api-problem-rest-test.xqm';

let $f := function-lookup(xs:QName('t:template-test'), 3)
return $f(<node/>, map{'':''}, '')
(:t:test5():)