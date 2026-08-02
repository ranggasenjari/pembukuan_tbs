import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/relation_agent_model.dart';
import '../../providers/providers.dart';
import 'relation_agent_entry_screen.dart';

class RelationAgentListScreen extends ConsumerStatefulWidget {
  const RelationAgentListScreen({super.key});

  @override
  ConsumerState<RelationAgentListScreen> createState() =>
      _RelationAgentListScreenState();
}

class _RelationAgentListScreenState
    extends ConsumerState<RelationAgentListScreen> {
  late Future<List<RelationAgentModel>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = ref
          .read(relationAgentRepositoryProvider)
          .getRelationAgents(query: _query);
    });
  }

  Future<void> _openForm([RelationAgentModel? relationAgent]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RelationAgentEntryScreen(relationAgent: relationAgent),
      ),
    );
    if (result == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          'Relasi / Agen',
          style: TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await _future;
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama, alamat, kontak...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  _query = value;
                  _refresh();
                },
              ),
            ),
            Expanded(
              child: FutureBuilder<List<RelationAgentModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Icon(
                          Icons.groups_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Belum ada data relasi / agen.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildCard(items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF4318FF),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Relasi'),
      ),
    );
  }

  Widget _buildCard(RelationAgentModel item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openForm(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: Color(0xFF1B2559),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          item.contact?.isNotEmpty == true
                              ? item.contact!
                              : '-',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              if (item.address?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  item.address!,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 12),
              Chip(label: Text('${item.accounts.length} Rekening')),
            ],
          ),
        ),
      ),
    );
  }
}
