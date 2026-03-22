'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const { validateUser } = require('../users');

const router = express.Router();

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Please try again later.' },
});

// Redirect root to login.
router.get('/', (req, res) => {
  if (req.session && req.session.username) {
    return res.redirect('/dashboard');
  }
  res.redirect('/login');
});

// Show the login page.
router.get('/login', (req, res) => {
  if (req.session && req.session.username) {
    return res.redirect('/dashboard');
  }
  res.sendFile('login.html', { root: 'public' });
});

// Handle login form submission.
router.post('/login', loginLimiter, async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  const valid = await validateUser(username, password);
  if (!valid) {
    return res.status(401).json({ error: 'Invalid username or password' });
  }

  req.session.username = username;
  res.json({ success: true, redirect: '/dashboard' });
});

// Handle logout.
router.post('/logout', (req, res) => {
  req.session.destroy(() => {
    res.redirect('/login');
  });
});

module.exports = router;
