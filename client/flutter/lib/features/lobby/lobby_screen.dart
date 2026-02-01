import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/room_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/socket_provider.dart';
import 'widgets/room_card.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lobbyRoomsProvider.notifier).subscribe();
      ref.read(lobbyRoomsProvider.notifier).fetchRooms();
    });
  }

  void _showCreateRoomDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Room'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Room Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final roomData = await api.createRoom(name);
                final roomId = roomData['id'] as String;
                final auth = ref.read(authStateProvider);
                ref.read(currentRoomProvider.notifier).joinRoom(
                      roomId,
                      auth.displayName ?? auth.userId ?? 'Anonymous',
                    );
                if (mounted) context.go('/room/$roomId');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create room: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(lobbyRoomsProvider);
    final auth = ref.watch(authStateProvider);
    final connected = ref.watch(socketConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SYNCWATCH'),
        actions: [
          // Connection status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: connected.when(
              data: (isConnected) => Icon(
                isConnected ? Icons.cloud_done : Icons.cloud_off,
                color: isConnected ? Colors.green : Colors.red,
              ),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Icon(Icons.cloud_off, color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(lobbyRoomsProvider.notifier).fetchRooms(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(socketServiceProvider).disconnect();
              ref.read(authStateProvider.notifier).logout();
              ref.read(serverInfoProvider.notifier).reset();
              context.go('/');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
      ),
      body: rooms.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.movie_filter, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No rooms available',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create one to get started!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return RoomCard(
                  room: room,
                  onJoin: () {
                    final displayName = auth.displayName ??
                        auth.userId ??
                        'Anonymous';
                    ref.read(currentRoomProvider.notifier).joinRoom(
                          room.id,
                          displayName,
                        );
                    context.go('/room/${room.id}');
                  },
                );
              },
            ),
    );
  }
}
