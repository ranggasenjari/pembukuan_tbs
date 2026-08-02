const { getSystemSupabaseClient } = require('../services/systemSupabase');

async function publicAuth(req, res, next) {
  try {
    req.supabase = await getSystemSupabaseClient();
    next();
  } catch (error) {
    next(error);
  }
}

module.exports = { publicAuth };
