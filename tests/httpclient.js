!function($, axios) {
    function testGet(url, accept) {
        axios.get(url, {
            headers: {'Accept': accept}
        })
        .then(function(response) {
            // error found :-(
            const outputText = accept.indexOf('xml') > -1 ?
                response.data : JSON.stringify(response.data, null, 4)
            $("#status-code").html(response.status)
            $("#output").text(outputText)
        })
        .catch(function(error) {
            const outputText = error.response.headers['content-type'].indexOf('xml') > -1 ?
                error.response.data : JSON.stringify(error.response.data, null, 4)
            $("#status-code").html(error.response.status)
            $("#output").text(outputText)
        })
    }
    
    $("#test1 .xml").on('click', function() { testGet('test1', 'application/xml') })
    $("#test1 .json").on('click', function() { testGet('test1', 'application/json') })
    $("#test2 .xml").on('click', function() { testGet('test2', 'application/xml') })
    $("#test2 .json").on('click', function() { testGet('test2', 'application/json') })
    $("#test3 .xml").on('click', function() { testGet('test3', 'application/xml') })
    $("#test3 .json").on('click', function() { testGet('test3', 'application/json') })
    $("#test4 .xml").on('click', function() { testGet('test4', 'application/xml') })
    $("#test4 .json").on('click', function() { testGet('test4', 'application/json') })
    $("#test5 .xml").on('click', function() { testGet('test5', 'application/xml') })
    $("#test5 .json").on('click', function() { testGet('test5', 'application/json') })
    $("#test6 .xml").on('click', function() { testGet('test6', 'application/xml') })
    $("#test6 .json").on('click', function() { testGet('test6', 'application/json') })
    $("#test7 .xml").on('click', function() { testGet('test7', 'application/xml') })
    $("#test7 .json").on('click', function() { testGet('test7', 'application/json') })
    $("#test8 .xml").on('click', function() { testGet('test8', 'application/xml') })
    $("#test8 .json").on('click', function() { testGet('test8', 'application/json') })
    $("#test9 .xml").on('click', function() { testGet('test9', 'application/xml') })
    $("#test9 .json").on('click', function() { testGet('test9', 'application/json') })
    $("#generic-error-in-restxq .xml").on('click', function() { testGet('generic-error-in-restxq', 'application/xml') })
    $("#generic-error-in-restxq .json").on('click', function() { testGet('generic-error-in-restxq', 'application/json') })
    $("#testxq .xml").on('click', function() { testGet('test.xq', 'application/xml') })
    $("#testxq .json").on('click', function() { testGet('test.xq', 'application/json') })
    $("#doesntexist .xml").on('click', function() { testGet('doesntexist.html', 'application/xml') })
    $("#doesntexist .json").on('click', function() { testGet('doesntexist.html', 'application/json') })
    $("#http_xqm .xml").on('click', function() { testGet('http.xqm', 'application/xml') })
    $("#http_xqm .json").on('click', function() { testGet('http.xqm', 'application/json') })
    $("#access-denied .xml").on('click', function() { testGet('access-denied.html', 'application/xml') })
    $("#access-denied .json").on('click', function() { testGet('access-denied.html', 'application/json') })
}(jQuery, axios)