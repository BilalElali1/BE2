'use strict';

const express = require('express');
const session = require('express-session');
const rateLimit = require('express-rate-limit');

const { generateCsrfToken, csrfProtection } = require('./middleware/csrf');
const authRoutes = require('./routes/auth');
const dashboardRoutes = require('./routes/dashboard');

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(express.static('public'));

const sessionSecret = process.env.SESSION_SECRET;
if (!sessionSecret) {
  console.warn(
    'WARNING: SESSION_SECRET is not set. Using an insecure default. ' +
      'Set a strong, random SESSION_SECRET environment variable in production.'
  );
}

app.use(
  session({
    secret: sessionSecret || 'change-me-in-production',
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: 'strict',
      secure: process.env.NODE_ENV === 'production',
    },
  })
);

// Apply a general rate limiter to all routes to protect file-serving endpoints.
const generalLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(generalLimiter);

// CSRF protection: validate the synchronizer token on mutation requests.
app.use(csrfProtection);

// Expose the CSRF token to client-side scripts via a JSON endpoint.
// Generating a token persists the session so subsequent POSTs share the same session.
app.get('/api/csrf-token', (req, res, next) => {
  const token = generateCsrfToken(req);
  req.session.save((err) => {
    if (err) return next(err);
    res.json({ csrfToken: token });
  });
});

app.use(authRoutes);
app.use(dashboardRoutes);

const PORT = process.env.PORT || 3000;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = { app };
