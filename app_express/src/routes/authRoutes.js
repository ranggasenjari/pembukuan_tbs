const express = require('express');
const { createAnonClient } = require('../config/supabase');
const { asyncHandler } = require('../middleware/asyncHandler');
const { redirectIfAuthenticated } = require('../middleware/auth');

const router = express.Router();

router.get('/login', redirectIfAuthenticated, (req, res) => {
  res.render('auth/login', { title: 'Login' });
});

router.post('/login', redirectIfAuthenticated, asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  const supabase = createAnonClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email: String(email || '').trim(),
    password: String(password || '').trim()
  });

  if (error || !data.session) {
    req.flash('error', error?.message || 'Login gagal.');
    return res.redirect('/login');
  }

  req.session.supabase = {
    access_token: data.session.access_token,
    refresh_token: data.session.refresh_token,
    expires_at: data.session.expires_at,
    user: data.user
  };
  return res.redirect('/dashboard');
}));

router.post('/logout', (req, res) => {
  req.session.destroy(() => res.redirect('/login'));
});

module.exports = router;
