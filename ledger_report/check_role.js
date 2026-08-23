require('dotenv').config();
const key = process.env.SUPABASE_KEY;
function decodeRole(k) {
  try {
    const payload = k.split('.')[1];
    const json = JSON.parse(Buffer.from(payload.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString());
    return { role: json.role, exp: json.exp ? new Date(json.exp * 1000).toISOString() : null };
  } catch (e) { return { error: e.message }; }
}
console.log('SUPABASE_URL=' + process.env.SUPABASE_URL);
console.log('SCHEMA=' + process.env.SUPABASE_SCHEMA);
console.log('KEY_ROLE=' + JSON.stringify(decodeRole(key)));