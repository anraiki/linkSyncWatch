import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

const _kServerUrlKey = 'last_server_url';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start with the provider default, then overwrite with saved value
    _serverUrlController.text = ref.read(serverUrlProvider);
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kServerUrlKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      _serverUrlController.text = saved;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    var url = _serverUrlController.text.trim();
    if (url.isEmpty) return;

    // Normalize: strip trailing slash
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    final success =
        await ref.read(serverInfoProvider.notifier).connect(url);
    if (success) {
      // Persist for next launch
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kServerUrlKey, url);
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverInfoProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SYNCWATCH',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Synchronized watch parties',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 48),

                TextField(
                  controller: _serverUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Server Address',
                    hintText: 'http://localhost:3000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: 16),

                if (serverState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      serverState.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: serverState.isLoading ? null : _connect,
                    icon: serverState.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
