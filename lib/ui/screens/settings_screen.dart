import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/models/household.dart';

/// Edits the synced household configuration and the per-device connection
/// settings (server / Ollama). Household changes sync immediately; device
/// changes are persisted and applied on next launch.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _dietary;
  late final TextEditingController _onHand;
  late final TextEditingController _servings;
  late final TextEditingController _serverUrl;
  late final TextEditingController _ollamaUrl;
  late final TextEditingController _model;
  final _members = <String>[];
  String _aiMode = 'direct';

  @override
  void initState() {
    super.initState();
    _dietary = TextEditingController();
    _onHand = TextEditingController();
    _servings = TextEditingController();
    _serverUrl = TextEditingController();
    _ollamaUrl = TextEditingController();
    _model = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _dietary,
      _onHand,
      _servings,
      _serverUrl,
      _ollamaUrl,
      _model
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of(context);
    final h = store.household ?? const HouseholdSettings(updatedAt: '0', version: 0);

    // Seed the fields from current state when they are empty (first build).
    if (_dietary.text.isEmpty) {
      _dietary.text = h.dietary.join(', ');
      _onHand.text = h.onHand.join(', ');
      _servings.text = '${h.defaultServings}';
      for (final m in h.members) {
        _members.add(m.name);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Šeima', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(controller: _dietary, decoration: const InputDecoration(labelText: 'Dietos apribojimai (atskirtas kableliais)'), onChanged: (_) => setState(() {})),
        TextField(controller: _servings, decoration: const InputDecoration(labelText: 'Numatytos porcijos'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
        const Text('Šeimos nariai', style: TextStyle(fontWeight: FontWeight.bold)),
        for (var i = 0; i < _members.length; i++)
          TextField(
            key: ValueKey('member-$i'),
            decoration: const InputDecoration(labelText: 'Vardas'),
            onChanged: (v) => setState(() => _members[i] = v),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _members.add('')),
            icon: const Icon(Icons.person_add),
            label: const Text('Pridėti narį'),
          ),
        ),
        const Divider(),
        const Text('Jau turimi ingredientai', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(controller: _onHand, decoration: const InputDecoration(labelText: 'Atskirta kableliais'), onChanged: (_) => setState(() {})),
        ElevatedButton(
          onPressed: () => _saveHousehold(context, store),
          child: const Text('Išsaugoti šeimą'),
        ),
        const Divider(),
        const Text('Ryšys (įrenginys)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextField(controller: _serverUrl, decoration: const InputDecoration(labelText: 'Serverio URL (pvz. http://192.168.1.10:8080)'), onChanged: (_) => setState(() {})),
        TextField(controller: _ollamaUrl, decoration: const InputDecoration(labelText: 'Ollama URL'), onChanged: (_) => setState(() {})),
        TextField(controller: _model, decoration: const InputDecoration(labelText: 'Modelis'), onChanged: (_) => setState(() {})),
        DropdownButtonFormField<String>(
          value: _aiMode,
          items: const [
            DropdownMenuItem(value: 'direct', child: Text('Tiesiogiai į Ollamą')),
            DropdownMenuItem(value: 'relay', child: Text('Per serverį (relay)')),
          ],
          onChanged: (v) => setState(() => _aiMode = v ?? 'direct'),
        ),
        ElevatedButton(
          onPressed: () => _saveDevice(context, store),
          child: const Text('Išsaugoti ryšį (veiks paleidus)'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => store.syncNow().then((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sinchronizuota')));
            }
          }),
          icon: const Icon(Icons.sync),
          label: const Text('Sinchronizuoti dabar'),
        ),
      ],
    );
  }

  Future<void> _saveHousehold(BuildContext context, AppStore store) async {
    final h = store.household ?? const HouseholdSettings(updatedAt: '0', version: 0);
    final members = _members
        .where((n) => n.trim().isNotEmpty)
        .map((name) => FamilyMember(id: name.trim(), name: name.trim()))
        .toList();
    final updated = h.copyWith(
      dietary: _split(_dietary.text),
      onHand: _split(_onHand.text),
      defaultServings: int.tryParse(_servings.text.trim()) ?? h.defaultServings,
      members: members,
    );
    await store.saveHousehold(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Šeima išsaugota')));
    }
  }

  Future<void> _saveDevice(BuildContext context, AppStore store) async {
    await store.config.setServerUrl(_serverUrl.text);
    await store.config.setOllamaUrl(_ollamaUrl.text);
    await store.config.setModel(_model.text);
    await store.config.setAiMode(_aiMode);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Išsaugota. Pakeitimai veiks paleidus programėlę.')));
    }
  }

  List<String> _split(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
