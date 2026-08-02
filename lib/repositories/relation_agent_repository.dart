import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/relation_agent_model.dart';

class RelationAgentRepository {
  final SupabaseClient _client;

  RelationAgentRepository(this._client);

  Future<List<RelationAgentModel>> getRelationAgents({String? query}) async {
    var request = _client
        .from('relation_agents')
        .select('*, relation_agent_accounts(*)');

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      request = request.or(
        'name.ilike.%$q%,address.ilike.%$q%,contact.ilike.%$q%',
      );
    }

    final response = await request.order('name', ascending: true);
    return (response as List)
        .map((e) => RelationAgentModel.fromJson(e))
        .toList();
  }

  Future<RelationAgentModel> getRelationAgent(String id) async {
    final response = await _client
        .from('relation_agents')
        .select('*, relation_agent_accounts(*)')
        .eq('id', id)
        .single();
    return RelationAgentModel.fromJson(response);
  }

  Future<void> createRelationAgent(RelationAgentModel relationAgent) async {
    await _client.from('relation_agents').insert(relationAgent.toJson());
    await _replaceChildren(relationAgent);
  }

  Future<void> updateRelationAgent(RelationAgentModel relationAgent) async {
    final data = relationAgent.toJson()
      ..remove('id')
      ..remove('created_at');
    await _client
        .from('relation_agents')
        .update(data)
        .eq('id', relationAgent.id);
    await _replaceChildren(relationAgent);
  }

  Future<void> deleteRelationAgent(String id) async {
    await _client
        .from('relation_agent_accounts')
        .delete()
        .eq('relation_agent_id', id);
    await _client.from('relation_agents').delete().eq('id', id);
  }

  Future<void> _replaceChildren(RelationAgentModel relationAgent) async {
    await _client
        .from('relation_agent_accounts')
        .delete()
        .eq('relation_agent_id', relationAgent.id);

    final accounts = relationAgent.accounts
        .where(
          (item) =>
              item.accountName.isNotEmpty || item.accountNumber.isNotEmpty,
        )
        .map((item) => item.toJson()..remove('id'))
        .toList();
    if (accounts.isNotEmpty) {
      await _client.from('relation_agent_accounts').insert(accounts);
    }
  }
}
