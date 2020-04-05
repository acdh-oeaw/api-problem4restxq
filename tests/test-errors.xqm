xquery version "3.1";

module namespace _ = "https://tools.ietf.org/html/rfc7807/test-errors";

declare function _:error-out-int() {
    xs:integer('ABCD')
};