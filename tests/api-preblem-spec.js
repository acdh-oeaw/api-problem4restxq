import { expect, describe, it, AssertionError } from 'vitest';
import { ofetch } from "ofetch";

/* BaseX (and others) provide valuabel information with a 400/500 so display them if the status code is wrong. */
async function onResponseError ({ options, response }) {
    if (response.status !== options.status) {
        return new Error('expected ' + options.status + ' "' + a + '", got ' + response.status + ' "' + b + '":\n ' + response.body);
    }
};

describe('API Problem reporting XML', async () => {
    const baseURL = 'http://localhost:8984';
    it('should run test1', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test1', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(500)
        expect(err.statusMessage).to.equal('_:an-error: testError Test1 Test2 Test3')
        const errBody = await err.data.text()
        expect(errBody).to.match(/testError Test1 Test2 Test3<\/title>/)
      }
    });
    it('should run test2', async () => {
      try {
        const res = await ofetch.raw('/api-problem-tests/test2', {baseURL, method: "GET"})
        expect(res.status).to.equal(200)
        expect(res.statusText).to.equal('OK')
        expect(res._data).to.equal("Test OK!  Test1 Test2 Test3")
      } catch (err) {
        if (err.name === "FetchError")
          expect(err).to.be.undefined("No error expected")
        throw err
      }
    });
    it('should run test3', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test3', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(402)
        expect(err.statusMessage).to.equal('You do not have enough credit.')
        const errBody = await err.data.text()
        expect(errBody).to.match(/Your current balance is 30, but that costs 50.<\/detail>/)
      }
    });
    it('should run test4', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test4', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(403)
        expect(err.statusMessage).to.equal('response-codes:_403: Test access denied!')
        const errBody = await err.data.text()
        expect(errBody).to.match(/Test access denied!<\/title>/)
      }
    });
    it('should run test5', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test5', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(403)
        expect(err.statusMessage).to.equal('https://tools.ietf.org/html/rfc7231#section-6/_403: Test access denied!')
        const errBody = await err.data.text()
        expect(errBody).to.match(/Test access denied!<\/title>/)
      }
    });
    it('should run test6', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test6', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(500)
        expect(err.statusMessage).to.match(/http:\/\/www.w3.org\/2005\/xqt-errors\/FORG0001: Cannot convert (xs:string )?to xs:integer: "?ABCD"?./)
        const errBody = await err.data.text()
        expect(errBody).to.match(/"?ABCD"?.<\/title>/)
      }
    });
    it('should run test7', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test7', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(500)
        expect(err.statusMessage).to.equal('_:an-error: testError Test1 Test2 Test3')
        const errBody = await err.data.text()
        expect(errBody).to.match(/testError Test1 Test2 Test3<\/title>/)
      }
    });
    it('should run test8', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test8', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(500)
        expect(err.statusMessage).to.match(/err:FORG0001 > _:catch-and-error: Cannot convert (xs:string )?to xs:integer: "?ABCD"?. > Catch and error/)
        const errBody = await err.data.text()
        expect(errBody).to.match(/Catch and error<\/title>/)
      }
    });
    it('should run test9', async () => {
      try {
        const res = await ofetch.raw('/api-problem-tests/test9', {baseURL, method: "GET", redirect: 'manual'})
        expect(res.status).to.equal(302)
        expect(res.statusText).to.equal('response-codes:_302: Moved Temporarily')
        const fwdBody = await res._data.text()
        expect(fwdBody).to.match(/_302: Moved Temporarily<\/title>/)
      } catch (err) {
        if (err.name === "FetchError")
          expect(err).to.be.undefined("No error expected")
        throw err
      }
    });
    it('should run test doesntexist.html', async () => {
      try {
        await ofetch.raw('/api-problem-tests/doesntexist.html', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(404)
        expect(err.statusMessage).to.equal('https://tools.ietf.org/html/rfc7231#section-6/_404: Not Found')
        const errBody = await err.data.text()
        expect(errBody).to.match(/_404: Not Found<\/title>/)
      }
    });
    it('should run test http.xqm', async () => {
      try {
        await ofetch.raw('/api-problem-tests/http.xqm', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(403)
        expect(err.statusMessage).to.equal('https://tools.ietf.org/html/rfc7231#section-6/_403: Forbidden')
        const errBody = await err.data.text()
        expect(errBody).to.match(/_403: Forbidden<\/title>/)
      }
    });
    it('should run test access-denied.html', async () => {
      try {
        await ofetch.raw('/api-problem-tests/access-denied.html', {baseURL, method: "GET"})
      } catch (err) {
        expect(err.status).to.equal(401)
        expect(err.statusMessage).to.equal('https://tools.ietf.org/html/rfc7231#section-6/_401: Unauthorized')
        const errBody = await err.data.text()
        expect(errBody).to.match(/_401: Unauthorized<\/title>/)
      }
    });
});

describe('API Problem reporting JSON', function() {
    const baseURL = 'http://localhost:8984';
    it('should run test1', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test1', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(500)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.equal('_:an-error: testError Test1 Test2 Test3')
        expect(err.data.title).to.match(/testError Test1 Test2 Test3/)
      }
    });
    it('should run test2', async () => {
      try {
        const res = await ofetch.raw('/api-problem-tests/test2', {baseURL, method: "GET", headers: {accept: "application/json"}})
        expect(res.status).to.equal(200)
        expect(res.statusText).to.equal('OK')
        expect(res.headers.get('content-type')).to.match(/\/json/)
        expect(res._data.message).to.equal("Test OK!")
        expect(res._data.param1).to.equal(" Test1")
        expect(res._data.param2).to.equal(" Test2")
        expect(res._data.param3).to.equal(" Test3")
      } catch (err) {
        if (err.name === "FetchError")
          expect(err).to.be.undefined("No error expected")
        throw err
      }
    });
    it('should run test3', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test3', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(402)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.equal('You do not have enough credit.')
        expect(err.data.detail).to.match(/Your current balance is 30, but that costs 50./)
      }
    });
    it('should run test4', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test4', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(403)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.equal('response-codes:_403: Test access denied!')
        expect(err.data.title).to.match(/Test access denied!/)
        expect(err.data.trace).to.match(/api-problem.xqm/)
      }
    });
    it('should run test5', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test5', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(403)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.equal('https://tools.ietf.org/html/rfc7231#section-6/_403: Test access denied!')
        expect(err.data.title).to.match(/Test access denied!/)
        expect(err.data.trace).to.not.match(/api-problem.xqm/)
      }
    });
    it('should run test6', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test6', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(500)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.match(/http:\/\/www.w3.org\/2005\/xqt-errors\/FORG0001: Cannot convert (xs:string )?to xs:integer: "?ABCD"?./)
        expect(err.data.title).to.match(/"?ABCD"?/)
      }
    });
    it('should run test7', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test7', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(500)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.equal('_:an-error: testError Test1 Test2 Test3')
        expect(err.data.title).to.match(/testError Test1 Test2 Test3/)
      }
    });
    it('should run test8', async () => {
      try {
        await ofetch.raw('/api-problem-tests/test8', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(500)
        expect(err.statusMessage).to.match(/err:FORG0001 > _:catch-and-error: Cannot convert (xs:string )?to xs:integer: "?ABCD"?. > Catch and error/)
        expect(err.data.title).to.match(/Catch and error/)
      }
    });
    it('should run test9', async () => {
      try {
        const res = await ofetch.raw('/api-problem-tests/test9', {baseURL, method: "GET", headers: {accept: "application/json"}, redirect: 'manual'})
        expect(res.status).to.equal(302)
        expect(res.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(res.statusText).to.equal('response-codes:_302: Moved Temporarily')
        expect(res._data.title).to.match(/_302: Moved Temporarily/)
      } catch (err) {
        if (err.name === "FetchError")
          expect(err).to.be.undefined("No error expected")
        throw err
      }
    });
    it('should run doesntexist.html', async () => {
      try {
        await ofetch.raw('/api-problem-tests/doesntexist.html', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(404)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.equal('https://tools.ietf.org/html/rfc7231#section-6/_404: Not Found')
        expect(err.data.title).to.match(/_404: Not Found/)
      }
    });
    it('should run http.xqm', async () => {
      try {
        await ofetch.raw('/api-problem-tests/http.xqm', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(403)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.equal('https://tools.ietf.org/html/rfc7231#section-6/_403: Forbidden')
        expect(err.data.title).to.match(/_403: Forbidden/)
      }
    });
    it('should run access-denied.html', async () => {
      try {
        await ofetch.raw('/api-problem-tests/access-denied.html', {baseURL, method: "GET", headers: {accept: "application/json"}})
      } catch (err) {
        expect(err.status).to.equal(401)
        expect(err.response.headers.get('content-type')).to.match(/\/problem\+json/)
        expect(err.statusMessage).to.equal('https://tools.ietf.org/html/rfc7231#section-6/_401: Unauthorized')
        expect(err.data.title).to.match(/_401: Unauthorized/)
      }
    });
});