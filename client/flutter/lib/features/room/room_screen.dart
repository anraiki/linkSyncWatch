import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/room_provider.dart';
import 'widgets/player_widget.dart';
import 'widgets/user_list.dart';
import 'widgets/queue_list.dart';
import 'widgets/operator_controls.dart';
import 'widgets/chat_widget.dart';

class RoomScreen extends ConsumerWidget {
  final String roomId;

  const RoomScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(currentRoomProvider);
    final room = roomState.room;

    if (room == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/lobby'),
          ),
          title: const Text('Connecting...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(currentRoomProvider.notifier).leaveRoom();
            context.go('/lobby');
          },
        ),
        title: Text(room.name),
        actions: [
          if (roomState.isOperator)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _WideLayout(roomState: roomState);
          }
          return _NarrowLayout(roomState: roomState);
        },
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  final RoomViewState roomState;

  const _WideLayout({required this.roomState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video player area
        Expanded(
          flex: 3,
          child: Row(
            children: [
              const Expanded(
                flex: 3,
                child: PlayerWidget(),
              ),
            ],
          ),
        ),

        // Bottom panel
        Expanded(
          flex: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Users panel
              const Expanded(
                child: UserListWidget(),
              ),

              const VerticalDivider(width: 1),

              // Chat panel
              const Expanded(
                child: ChatWidget(),
              ),

              const VerticalDivider(width: 1),

              // Queue + controls panel
              Expanded(
                child: Column(
                  children: [
                    const Expanded(child: QueueListWidget()),
                    if (roomState.isOperator) const OperatorControls(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  final RoomViewState roomState;

  const _NarrowLayout({required this.roomState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video player
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: PlayerWidget(),
        ),

        // Tabs for users, chat, and queue
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Chat'),
                    Tab(text: 'Users'),
                    Tab(text: 'Queue'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      const ChatWidget(),
                      const UserListWidget(),
                      Column(
                        children: [
                          const Expanded(child: QueueListWidget()),
                          if (roomState.isOperator) const OperatorControls(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
