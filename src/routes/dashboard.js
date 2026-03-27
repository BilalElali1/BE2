'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// Show the user dashboard (protected route).
router.get('/dashboard', requireAuth, (req, res) => {
  res.sendFile('dashboard.html', { root: 'public' });
});

// API endpoint to get current user info (protected).
router.get('/api/me', requireAuth, (req, res) => {
  res.json({ username: req.session.username });
});

module.exports = router;
