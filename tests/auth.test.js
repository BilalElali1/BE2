'use strict';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

// Silence the demo user seed log during tests.
process.env.PORT = '0';

let app, server, baseUrl;

before(async () => {
  ({ app } = require('../src/server'));
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  const { address, port } = server.address();
  baseUrl = `http://${address}:${port}`;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

/** Helper – perform a fetch-style request and return { status, headers, body } */
async function request(method, path, { body, headers = {}, cookieJar } = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, baseUrl);
    const opts = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: { ...headers },
    };

    if (body) {
      const json = JSON.stringify(body);
      opts.headers['Content-Type'] = 'application/json';
      opts.headers['Content-Length'] = Buffer.byteLength(json);
    }

    if (cookieJar && cookieJar.length) {
      opts.headers['Cookie'] = cookieJar.join('; ');
    }

    const req = http.request(opts, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString();
        resolve({ status: res.statusCode, headers: res.headers, body: text });
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

/** Extract Set-Cookie headers into a simple cookie jar array */
function extractCookies(res) {
  const raw = res.headers['set-cookie'] || [];
  return raw.map((c) => c.split(';')[0]);
}

/** Fetch a CSRF token and its associated cookie */
async function getCsrfToken(cookieJar = []) {
  const res = await request('GET', '/api/csrf-token', { cookieJar });
  const json = JSON.parse(res.body);
  const cookies = [...cookieJar, ...extractCookies(res)];
  return { csrfToken: json.csrfToken, cookies };
}

describe('GET /', () => {
  it('redirects to /login when not authenticated', async () => {
    const res = await request('GET', '/');
    assert.equal(res.status, 302);
    assert.match(res.headers.location, /\/login/);
  });
});

describe('GET /login', () => {
  it('returns 200 with the login page', async () => {
    const res = await request('GET', '/login');
    assert.equal(res.status, 200);
    assert.match(res.body, /Sign in/);
  });
});

describe('POST /login', () => {
  it('returns 400 when credentials are missing', async () => {
    const { csrfToken, cookies } = await getCsrfToken();
    const res = await request('POST', '/login', {
      body: {},
      headers: { 'x-csrf-token': csrfToken },
      cookieJar: cookies,
    });
    assert.equal(res.status, 400);
    const json = JSON.parse(res.body);
    assert.ok(json.error);
  });

  it('returns 401 for wrong credentials', async () => {
    const { csrfToken, cookies } = await getCsrfToken();
    const res = await request('POST', '/login', {
      body: { username: 'demo', password: 'wrongpassword' },
      headers: { 'x-csrf-token': csrfToken },
      cookieJar: cookies,
    });
    assert.equal(res.status, 401);
    const json = JSON.parse(res.body);
    assert.ok(json.error);
  });

  it('returns success and redirect path for valid credentials', async () => {
    const { csrfToken, cookies } = await getCsrfToken();
    const res = await request('POST', '/login', {
      body: { username: 'demo', password: 'password123' },
      headers: { 'x-csrf-token': csrfToken },
      cookieJar: cookies,
    });
    assert.equal(res.status, 200);
    const json = JSON.parse(res.body);
    assert.equal(json.success, true);
    assert.equal(json.redirect, '/dashboard');
  });
});

describe('GET /dashboard', () => {
  it('redirects to /login when not authenticated', async () => {
    const res = await request('GET', '/dashboard');
    assert.equal(res.status, 302);
    assert.match(res.headers.location, /\/login/);
  });

  it('returns 200 with dashboard page when authenticated', async () => {
    const { csrfToken, cookies } = await getCsrfToken();
    const loginRes = await request('POST', '/login', {
      body: { username: 'demo', password: 'password123' },
      headers: { 'x-csrf-token': csrfToken },
      cookieJar: cookies,
    });
    const sessionCookies = [...cookies, ...extractCookies(loginRes)];

    const dashRes = await request('GET', '/dashboard', { cookieJar: sessionCookies });
    assert.equal(dashRes.status, 200);
    assert.match(dashRes.body, /Dashboard/);
  });
});

describe('GET /api/me', () => {
  it('returns 302 when not authenticated', async () => {
    const res = await request('GET', '/api/me');
    assert.equal(res.status, 302);
  });

  it('returns username when authenticated', async () => {
    const { csrfToken, cookies } = await getCsrfToken();
    const loginRes = await request('POST', '/login', {
      body: { username: 'demo', password: 'password123' },
      headers: { 'x-csrf-token': csrfToken },
      cookieJar: cookies,
    });
    const sessionCookies = [...cookies, ...extractCookies(loginRes)];

    const meRes = await request('GET', '/api/me', { cookieJar: sessionCookies });
    assert.equal(meRes.status, 200);
    const json = JSON.parse(meRes.body);
    assert.equal(json.username, 'demo');
  });
});

describe('POST /logout', () => {
  it('destroys the session and redirects to /login', async () => {
    const { csrfToken, cookies } = await getCsrfToken();
    const loginRes = await request('POST', '/login', {
      body: { username: 'demo', password: 'password123' },
      headers: { 'x-csrf-token': csrfToken },
      cookieJar: cookies,
    });
    const sessionCookies = [...cookies, ...extractCookies(loginRes)];

    const { csrfToken: logoutToken, cookies: logoutCookies } = await getCsrfToken(sessionCookies);
    const logoutRes = await request('POST', '/logout', {
      headers: { 'x-csrf-token': logoutToken },
      cookieJar: logoutCookies,
    });
    assert.equal(logoutRes.status, 302);
    assert.match(logoutRes.headers.location, /\/login/);

    // After logout the session cookie should no longer grant access.
    const dashRes = await request('GET', '/dashboard', { cookieJar: sessionCookies });
    assert.equal(dashRes.status, 302);
  });
});
