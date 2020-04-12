xquery version "3.1";

import module namespace test="https://tools.ietf.org/html/rfc7807/tests" at "tests/api-problem-rest-test.xqm";
            
declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

declare function local:dispatcher() {
  switch (true())
    case $exist:path = ('/tests/test.html', '/tests/test2.html', '/tests/access-denied.html') return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <set-header name="Cache-Control" value="no-cache"/>
            <forward url="{$exist:controller}/tests/view.xql"/>
        </view>
        <error-handler>
            <forward url="{$exist:controller}/tests/error-page.html" method="get"/>
            <forward url="{$exist:controller}/catch-all-handler.xql">
              <!-- if you want to have any useful information on access denied (401) errors from exist
                   you have to pass the path that was requested as attribute -->
              <set-attribute name="api-problem.requested-filename" value="{$exist:root}{$exist:prefix}{$exist:controller}{$exist:path}"/>
              <!-- you have to set this to the path that is used to resolve template files -->
              <set-attribute name="templates.app-root" value="/db/apps/api-problem/tests/"/>
            </forward>
        </error-handler>
      </dispatch>
    case $exist:path = ('/tests-with-catch/test.html', '/tests-with-catch/test2.html', '/tests-with-catch/access-denied.html', '/tests-with-catch/test3.html') return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/tests/{$exist:resource}"/>
        <view>
            <set-header name="Cache-Control" value="no-cache"/>
            <forward url="{$exist:controller}/tests/view-with-catch.xql"/>
        </view>
        <!-- There are two options here:
             * use an error-handler that also catches problems in error handling in your view.xql
               or 401 errors
               -> you have to report errors as rfc7807:problem, final rendering is done by catch-all-handler.xql
             * don't use an error handler here and do the final rendering in your view.xql -->
        <error-handler>
            <forward url="{$exist:controller}/tests/error-page.html" method="get"/>
            <forward url="{$exist:controller}/catch-all-handler.xql">
              <!-- if you want to have any useful information on access denied (401) errors from exist
                   you have to pass the path that was requested as attribute -->
              <set-attribute name="api-problem.requested-filename" value="{$exist:root}{$exist:prefix}{$exist:controller}/tests/{$exist:resource}"/>
              <set-attribute name="templates.app-root" value="/db/apps/api-problem/tests/"/>
            </forward>
        </error-handler>
      </dispatch>
    case $exist:path = '/tests/test.xq' return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/tests/test.xq"/>
        <error-handler>
          <forward url="{$exist:controller}/tests/error-page.html" method="get"/>
          <forward url="{$exist:controller}/catch-all-handler.xql">
            <set-attribute name="api-problem.set-status-code.workaround" value="true"/>
            <set-attribute name="templates.app-root" value="/db/apps/api-problem/tests/"/>
          </forward>
        </error-handler>
      </dispatch>
    case starts-with($exist:path, '/tests') return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/restxq{$exist:path}" absolute="yes"/>
        <!-- Because this is forwarded to another servelet error-handler does not work here, you need to use error-page -->
      </dispatch>
    (: boiler plate logic to redirect to index.html in all variants people usually use :)
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
    (: use api-problem to report file not found for anything else whether it actually exists or not :)
    default return
      <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/tests/error-page.html" method="get"/>
        <view>
          <forward url="{$exist:controller}/catch-all-handler.xql">
            <set-attribute name="javax.servlet.error.status_code" value="404"/>
            <set-attribute name="javax.servlet.error.message" value="Not Found"/>
            <set-attribute name="api-problem.requested-filename" value="{$exist:root}{$exist:prefix}{$exist:controller}{$exist:path} (controller.xql refused to find this)"/>
            <set-attribute name="templates.app-root" value="/db/apps/api-problem/tests/"/>
          </forward>
        </view>
      </dispatch>
};

local:dispatcher()