const { expect } = require('chai');
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

describe('API Problem reporting XML', function() {
    const baseURI = 'http://localhost:8984';
    it('should run test1', function(){
        return request(baseURI)
          .get('/api-problem-tests/test1')
          .expect(500, /testError Test1 Test2 Test3<\/title>/)
    });
    it('should run test2', function(){
        return request(baseURI)
          .get('/api-problem-tests/test2')
          .expect(200, "Test OK!  Test1 Test2 Test3")
    });
    it('should run test3', function(){
        return request(baseURI)
          .get('/api-problem-tests/test3')
          .expect(402, /Your current balance is 30, but that costs 50.<\/detail>/)
    });
    it('should run test4', function(){
        return request(baseURI)
          .get('/api-problem-tests/test4')
          .expect(403, /Test access denied!<\/title>/)
    });
    it('should run test5', function(){
        return request(baseURI)
          .get('/api-problem-tests/test5')
          .expect(403, /Test access denied!<\/title>/)
    });
    it('should run test6', function(){
        return request(baseURI)
          .get('/api-problem-tests/test6')
          .expect(500, /"ABCD".<\/title>/)
    });
    it('should run test7', function(){
        return request(baseURI)
          .get('/api-problem-tests/test7')
          .expect(500, /testError Test1 Test2 Test3<\/title>/)
    });
    it('should run test8', function(){
        return request(baseURI)
          .get('/api-problem-tests/test8')
          .expect(500, /Catch and error<\/title>/)
    });
    it('should run test9', function(){
        return request(baseURI)
          .get('/api-problem-tests/test9')
          .expect(302, /_302: Moved Temporarily<\/title>/)
    });
    it('should run test doesntexist.html', function(){
        return request(baseURI)
          .get('/api-problem-tests/doesntexist.html')
          .expect(404, /_404: Not Found<\/title>/)
    });
    it('should run test http.xqm', function(){
        return request(baseURI)
          .get('/api-problem-tests/http.xqm')
          .expect(403, /_403: Forbidden<\/title>/)
    });
    it('should run test access-denied.html', function(){
        return request(baseURI)
          .get('/api-problem-tests/access-denied.html')
          .expect(401, /_401: Unauthorized<\/title>/)
    });
});

describe('API Problem reporting JSON', function() {
    const baseURI = 'http://localhost:8984';
    it('should run test1', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test1')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(500)
        expect(response.body.title).to.match(/testError Test1 Test2 Test3/)
    });
    it('should run test2', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test2')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/json/)
        expect(response.status).to.equal(200)
        expect(response.body.message).to.equal("Test OK!")
        expect(response.body.param1).to.equal(" Test1")
        expect(response.body.param2).to.equal(" Test2")
        expect(response.body.param3).to.equal(" Test3")
    });
    it('should run test3', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test3')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(402)
        expect(response.body.detail).to.match(/Your current balance is 30, but that costs 50./)
    });
    it('should run test4', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test4')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(403)
        expect(response.body.title).to.match(/Test access denied!/)
        expect(response.body.trace).to.match(/api-problem.xqm/)
    });
    it('should run test5', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test5')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(403)
        expect(response.body.title).to.match(/Test access denied!/)
        expect(response.body.trace).to.not.match(/api-problem.xqm/)
    });
    it('should run test6', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test6')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(500)
        expect(response.body.title).to.match(/"ABCD"/)
    });
    it('should run test7', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test7')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(500)
        expect(response.body.title).to.match(/testError Test1 Test2 Test3/)
    });
    it('should run test8', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test8')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(500)
        expect(response.body.title).to.match(/Catch and error/)
    });
    it('should run test9', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/test9')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(302)
        expect(response.body.title).to.match(/_302: Moved Temporarily/)
    });
    it('should run test doesntexist.html', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/doesntexist.html')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(404)
        expect(response.body.title).to.match(/_404: Not Found/)
    });
    it('should run test http.xqm', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/http.xqm')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(403)
        expect(response.body.title).to.match(/_403: Forbidden/)
    });
    it('should run test access-denied.html', async function(){
        const response = await request(baseURI)
          .get('/api-problem-tests/access-denied.html')
          .set('Accept', 'application/json')
        expect(response.headers['content-type']).to.match(/\/problem\+json/)
        expect(response.status).to.equal(401)
        expect(response.body.title).to.match(/_401: Unauthorized/)
    });
});