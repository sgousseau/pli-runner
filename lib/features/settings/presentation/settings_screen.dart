import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pli_runner/core/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _tokenController = TextEditingController();
  final _messageController = TextEditingController();
  final _radiusController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsRepositoryProvider);
    _tokenController.text = await settings.getBotToken() ?? '';
    _messageController.text = await settings.getApproachMessage();
    _radiusController.text = (await settings.getGeofenceRadius()).round().toString();
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setBotToken(_tokenController.text.trim());
    await settings.setApproachMessage(_messageController.text.trim());
    await settings.setGeofenceRadius(double.tryParse(_radiusController.text) ?? 500);

    // Restart polling with new token
    final polling = ref.read(telegramPollingProvider);
    polling.stop();
    await polling.start();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres sauvegardés ✓')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _messageController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Sauver')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Telegram Bot',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    labelText: 'Bot Token',
                    hintText: '123456:ABC-DEF...',
                    helperText: 'Crée un bot via @BotFather sur Telegram',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Géofencing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _radiusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rayon de détection (mètres)',
                    helperText: '500m ≈ 3 min à pied',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Message d\'approche',
                    helperText: 'Utilise {clientNumber} pour le n° client',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Comment ça marche',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1. Crée un bot Telegram via @BotFather'),
                        Text('2. Colle le token ci-dessus'),
                        Text('3. Le dispatch envoie les photos au bot'),
                        Text('4. L\'app extrait automatiquement les adresses'),
                        Text('5. Quand tu approches → message auto au dispatch'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
