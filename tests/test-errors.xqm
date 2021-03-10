xquery version "3.1";

module namespace _ = "https://tools.ietf.org/html/rfc7807/test-errors";

import module namespace api-problem = "https://tools.ietf.org/html/rfc7807" at "../api-problem/api-problem.xqm";

declare namespace response-codes = "https://tools.ietf.org/html/rfc7231#section-6";

declare function _:error-out-int() {
    xs:integer('ABCD')
};

declare function _:redirect_error($new-location as xs:string) {
    error(
        xs:QName("response-codes:_302"),
        $api-problem:codes_to_message(302),
        map {$api-problem:ADDITIONAL_HEADER_ELEMENTS: map{
            'Location': $new-location
        }}
        )
};