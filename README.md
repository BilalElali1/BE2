# BE2

A simple Node.js/Express web application with user authentication and a personal dashboard.

## Features

- **Login page** – form-based authentication with error feedback
- **User dashboard** – protected page showing account info and session timer
- **Session management** – server-side sessions with secure cookies
- **Logout** – destroys the session and redirects to the login page

## Getting started

```bash
npm install
npm start
```

The server starts on <http://localhost:3000>.

### Demo credentials

| Username | Password    |
| -------- | ----------- |
| `demo`   | `password123` |

## Scripts

| Command       | Description              |
| ------------- | ------------------------ |
| `npm start`   | Start the server         |
| `npm run dev` | Start with file watching |
| `npm test`    | Run the test suite       |

## Environment variables

| Variable         | Default                    | Description                         |
| ---------------- | -------------------------- | ----------------------------------- |
| `PORT`           | `3000`                     | TCP port the server listens on      |
| `SESSION_SECRET` | `change-me-in-production`  | Secret used to sign session cookies |

> **Note**: Set a strong, random `SESSION_SECRET` in production.

## Project structure

```
src/
  server.js            # Express app entry point
  users.js             # In-memory user store (replace with DB in production)
  middleware/
    auth.js            # requireAuth middleware
  routes/
    auth.js            # GET/POST /login, POST /logout
    dashboard.js       # GET /dashboard, GET /api/me
public/
  login.html           # Login page
  dashboard.html       # User dashboard
tests/
  auth.test.js         # Integration tests (Node built-in test runner)
```

