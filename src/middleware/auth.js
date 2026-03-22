'use strict';

function requireAuth(req, res, next) {
  if (req.session && req.session.username) {
    return next();
  }
  res.redirect('/login');
}

module.exports = { requireAuth };
