xquery version "3.1";

import module namespace test="https://tools.ietf.org/html/rfc7807/tests" at "tests/api-problem-rest-test.xqm";
            
declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

declare function local:dispatcher() {
  switch (true())
    case $exist:path = '/tests/test.xq' return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/tests/test.xq"/>
        <error-handler>
          <forward url="{$exist:controller}/catch-all-handler.xql"/>
        </error-handler>
      </dispatch>
    case $exist:path = ('/tests/test.html', '/tests/test2.html') return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <!-- forward url="{$exist:controller}/tests/test.html" method="get"/ -->
        <view>
            <set-header name="Cache-Control" value="no-cache"/>
            <forward url="{$exist:controller}/tests/view.xql"/>
        </view>
        <error-handler>
            <forward url="{$exist:controller}/catch-all-handler.xql"/>
        </error-handler>
      </dispatch>     
    case starts-with($exist:path, '/tests') return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/restxq{$exist:path}" absolute="yes"/>
      </dispatch>
    case $exist:path = '' return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="api-problem/index.html"/>
      </dispatch>
    case $exist:path = '/' return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
      </dispatch>
    case $exist:path = '/index.html' return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/index.html"/>
      </dispatch>
    default return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/catch-all-handler.xql">
           <set-attribute name="javax.servlet.error.status_code" value="404"/>
           <set-attribute name="javax.servlet.error.message" value="Not Found"/>
        </forward>
      </dispatch>
};

local:dispatcher()