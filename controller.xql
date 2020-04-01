xquery version "3.1";
            
declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

switch (true())
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
case $exist:path = 'index.html' return
<dispatch xmlns="http://exist.sourceforge.net/NS/exist">
    <forward url="index.html"/>
</dispatch>
default return ()