import { json, toPublicUrl, userClient } from '../_shared/auth.ts'

Deno.serve(async (req) => {
  try {
    const supabase = userClient(req)
    const body = await req.json()
    let attachmentUrl: string | null = null
    if (body.attachment_path) {
      const { data } = supabase.storage.from('receipts').getPublicUrl(String(body.attachment_path))
      attachmentUrl = toPublicUrl(data.publicUrl)
    }
    const { data, error } = await supabase.schema('inv').rpc('apply_offline_sync', {
      p_device_id: String(body.device_id),
      p_operation_id: String(body.operation_id),
      p_entity_type: String(body.entity_type),
      p_payload: body.payload,
      p_attachment_url: attachmentUrl,
    })
    if (error) throw error
    const status = data?.status === 'conflict' ? 409 : 200
    return json(data, status)
  } catch (error) {
    return json({ status: 'error', message: String(error) }, 400)
  }
})
