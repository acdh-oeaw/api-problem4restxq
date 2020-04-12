xquery version "3.1";

(: This is a suggested method to share the template function resolver
 : between view.xql and catch-all-handler.xql.
 : catch-all-handler.xql gets a customize version of this module by
 : reading the templates.lookup-module attribute and uses the first
 : method in that module
 :)

module namespace templates-lookup="https://tools.ietf.org/html/rfc7807/tests/lookup";

(: The following modules provide functions which will be called by the html templates :)
import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace test="https://tools.ietf.org/html/rfc7807/tests" at "api-problem-rest-test.xqm";
(: Contains a few functions used by the error page :)
import module namespace api-problem="https://tools.ietf.org/html/rfc7807" at "../api-problem.xqm";

declare function templates-lookup:resolve($functionName as xs:string, $arity as xs:int) {
    function-lookup(xs:QName($functionName), $arity)
    (: we have a catch all elsewhere :)
};