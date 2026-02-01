import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/socket/socket_service.dart';
import 'auth_provider.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final socket = SocketService();
  ref.onDispose(() => socket.dispose());
  return socket;
});

final socketConnectedProvider = StreamProvider<bool>((ref) {
  final socket = ref.watch(socketServiceProvider);
  return socket.connectionStream;
});

void connectSocket(Ref ref) {
  final auth = ref.read(authStateProvider);
  final serverUrl = ref.read(serverUrlProvider);
  final socket = ref.read(socketServiceProvider);

  if (auth.token != null && !socket.isConnected) {
    socket.connect(serverUrl, auth.token!);
  }
}
