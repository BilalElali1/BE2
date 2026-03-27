'use strict';

const bcrypt = require('bcryptjs');

// In-memory user store for demo purposes.
// In production, replace with a real database.
const users = new Map();

async function createUser(username, password) {
  if (users.has(username)) {
    throw new Error('User already exists');
  }
  const hash = await bcrypt.hash(password, 10);
  users.set(username, { username, password: hash });
}

async function validateUser(username, password) {
  const user = users.get(username);
  if (!user) return false;
  return bcrypt.compare(password, user.password);
}

// Seed a default demo user on module load.
(async () => {
  await createUser('demo', 'password123');
})().catch((err) => {
  console.error('Failed to seed demo user:', err.message);
});

module.exports = { createUser, validateUser };
