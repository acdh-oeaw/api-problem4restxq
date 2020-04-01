const chai = require('chai')
    , chaiAsPromised = require("chai-as-promised")
    , http = require('http')
    , request = require('supertest');

/* register eventually and use the .should variety */
chai.use(chaiAsPromised);
chai.should();

/* BaseX (and others) provide valuabel information with a 400/500 so display them if the status code is wrong. */
request.Test.prototype._assertStatus = function (status, res) {
    var a = http.STATUS_CODES[status],
        b = http.STATUS_CODES[res.status];
    if (res.status !== status) {
        return new Error('expected ' + status + ' "' + a + '", got ' + res.status + ' "' + b + '":\n ' + res.text);
    }
};

describe('API Problem reporting', function() {
    const baseURI = 'https://exist5x.hephaistos.arz.oeaw.ac.at/exist/restxq';
    it('should run test1', function(){
        return request(baseURI)
          .get('/tests/test1')
          .expect(500, /testError Test1 Test2 Test3<\/title>/)
    });
    it('should run test2', function(){
        return request(baseURI)
          .get('/tests/test2')
          .expect(200, "Test OK!  Test1 Test2 Test3")
    });
    it('should run test3', function(){
        return request(baseURI)
          .get('/tests/test3')
          .set('Accept', 'application/xml')
          .expect(402, /Your current balance is 30, but that costs 50.<\/detail>/)
    });
    it('should run test4', function(){
        return request(baseURI)
          .get('/tests/test4')
          .set('Accept', 'application/xml')
          .expect(403, /Test access denied!<\/title>/)
    });
});