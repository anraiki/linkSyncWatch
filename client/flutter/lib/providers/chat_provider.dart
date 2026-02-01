import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import 'socket_provider.dart';
import 'room_provider.dart';

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  StreamSubscription? _sub;
  bool _hasMore = true;
  bool _loadingHistory = false;

  ChatNotifier(this._ref) : super([]) {
    final socket = _ref.read(socketServiceProvider);
    _sub = socket.chatMessageStream.listen((msg) {
      // Prepend new messages to the front (newest first in the list,
      // but the widget reverses, so insert at index 0).
      state = [msg, ...state];
    });
  }

  void loadInitialHistory() {
    final room = _ref.read(currentRoomProvider).room;
    if (room == null) return;

    state = [];
    _hasMore = true;

    _ref.read(socketServiceProvider).chatHistory(
      room.id,
      onResponse: (messages) {
        state = messages;
        _hasMore = messages.length >= 50;
      },
    );
  }

  void loadMore() {
    if (_loadingHistory || !_hasMore) return;
    final room = _ref.read(currentRoomProvider).room;
    if (room == null || state.isEmpty) return;

    _loadingHistory = true;
    final oldest = state.last.timestamp;

    _ref.read(socketServiceProvider).chatHistory(
      room.id,
      before: oldest,
      onResponse: (messages) {
        _loadingHistory = false;
        if (messages.isEmpty) {
          _hasMore = false;
          return;
        }
        state = [...state, ...messages];
        _hasMore = messages.length >= 50;
      },
    );
  }

  bool get hasMore => _hasMore;

  void sendMessage(String content) {
    final room = _ref.read(currentRoomProvider).room;
    if (room == null || content.trim().isEmpty) return;
    _ref.read(socketServiceProvider).chatSend(room.id, content.trim());
  }

  void clear() {
    state = [];
    _hasMore = true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
