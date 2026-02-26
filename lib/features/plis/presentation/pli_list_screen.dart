import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pli_runner/core/models/pli.dart';
import 'package:pli_runner/core/providers.dart';
import 'package:pli_runner/features/plis/presentation/pli_map_screen.dart';
import 'package:pli_runner/features/settings/presentation/settings_screen.dart';

class PliListScreen extends ConsumerStatefulWidget {
  const PliListScreen({super.key});

  @override
  ConsumerState<PliListScreen> createState() => _PliListScreenState();
}

class _PliListScreenState extends ConsumerState<PliListScreen> {
  @override
  void initState() {
    super.initState();
    // Start polling & geofencing after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final polling = ref.read(telegramPollingProvider);
      polling.start();
      polling.startGeofencing();
    });
  }

  @override
  Widget build(BuildContext context) {
    final plis = ref.watch(plisProvider);
    final pendingPlis = plis.where((p) => p.status == PliStatus.pending).toList();
    final donePlis = plis.where((p) => p.status != PliStatus.pending).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Pli Runner (${pendingPlis.length} en cours)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PliMapScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: plis.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Aucun pli pour le moment',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Configure ton bot Telegram dans les paramètres,\npuis demande au dispatch de t\'envoyer des photos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(plisProvider.notifier).refresh(),
              child: ListView(
                children: [
                  if (pendingPlis.isNotEmpty) ...[
                    _sectionHeader('À récupérer', pendingPlis.length),
                    ...pendingPlis.map((p) => _PliTile(pli: p)),
                  ],
                  if (donePlis.isNotEmpty) ...[
                    _sectionHeader('Terminés', donePlis.length),
                    ...donePlis.map((p) => _PliTile(pli: p)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '$title ($count)',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _PliTile extends ConsumerWidget {
  final Pli pli;

  const _PliTile({required this.pli});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (pli.status) {
      PliStatus.pending => Colors.orange,
      PliStatus.pickedUp => Colors.blue,
      PliStatus.delivered => Colors.green,
      PliStatus.failed => Colors.red,
    };

    final icon = switch (pli.status) {
      PliStatus.pending => Icons.schedule,
      PliStatus.pickedUp => Icons.local_shipping,
      PliStatus.delivered => Icons.check_circle,
      PliStatus.failed => Icons.error,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          '#${pli.clientNumber}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pli.address, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (!pli.hasCoordinates)
              const Text('GPS en cours...', style: TextStyle(fontSize: 11, color: Colors.orange)),
          ],
        ),
        trailing: pli.status == PliStatus.pending
            ? PopupMenuButton<PliStatus>(
                onSelected: (status) => ref.read(plisProvider.notifier).updatePliStatus(pli.id, status),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: PliStatus.pickedUp, child: Text('✓ Récupéré')),
                  const PopupMenuItem(value: PliStatus.delivered, child: Text('✓ Livré')),
                  const PopupMenuItem(value: PliStatus.failed, child: Text('✗ Échec')),
                ],
              )
            : null,
        isThreeLine: !pli.hasCoordinates,
      ),
    );
  }
}
