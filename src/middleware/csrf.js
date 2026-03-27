'use strict';

const crypto = require('node:crypto');

/** Generate a new CSRF token and store it in the session */
function generateCsrfToken(req) {
  const token = crypto.randomBytes(32).toString('hex');
  req.session.csrfToken = token;
  return token;
}

/** Express middleware: validate the CSRF token on mutation requests */
function csrfProtection(req, res, next) {
  const safeMethods = new Set(['GET', 'HEAD', 'OPTIONS']);
  if (safeMethods.has(req.method)) return next();

  const sessionToken = req.session && req.session.csrfToken;
  const requestToken = req.headers['x-csrf-token'];

  if (!sessionToken || !requestToken || sessionToken !== requestToken) {
    return res.status(403).json({ error: 'Invalid CSRF token' });
  }
  next();
}

module.exports = { generateCsrfToken, csrfProtection };
