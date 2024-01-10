xquery version "3.1";
module namespace _ = "uri:_";
declare namespace rest = "uri:rest";

(:~
 : Redirects to API path.
 : @return rest response
 :)
declare
  %rest:path('')
function _:index-file() as item()+ {
  <rest:response>
    <http:response status="302">
      <http:header name="Location" value="api-problem-tests/"/>
    </http:response>
  </rest:response>
};