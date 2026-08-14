import { json, toPublicUrl, userClient } from '../_shared/auth.ts'

Deno.serve(async (req) => {
  try {
    const supabase = userClient(req)
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return json({ status: 'error', message: 'Unauthorized' }, 401)
    const body = await req.json()
    const operationId = String(body.operation_id || '')
    const fileName = String(body.file_name || 'bon.jpg').replace(/[^A-Za-z0-9._-]/g, '_')
    if (!/^[0-9a-f-]{36}$/i.test(operationId)) return json({ status: 'error', message: 'Invalid operation id' }, 400)
    const objectPath = `offline/${user.id}/${operationId}/${fileName}`
    const { data, error } = await supabase.storage.from('receipts').createSignedUploadUrl(objectPath, { upsert: true })
    if (error) throw error
    return json({ object_path: objectPath, upload_url: toPublicUrl(data.signedUrl) })
  } catch (error) {
    return json({ status: 'error', message: String(error) }, 400)
  }
})
