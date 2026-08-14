import { json, userClient } from '../_shared/auth.ts'

Deno.serve(async (req) => {
  try {
    const supabase = userClient(req)
    const tables = [
      'factories', 'factory_spsi_types', 'factory_prices',
      'relation_agents', 'relation_agent_accounts', 'vehicles',
    ]
    const masters: Record<string, unknown> = {}
    for (const table of tables) {
      const { data, error } = await supabase.schema('inv').from(table).select('*')
      if (error) throw error
      masters[table] = data ?? []
    }
    return json({ version: new Date().toISOString(), masters })
  } catch (error) {
    return json({ status: 'error', message: String(error) }, 401)
  }
})
