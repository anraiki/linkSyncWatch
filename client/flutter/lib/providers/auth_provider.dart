import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final serverUrl = ref.watch(serverUrlProvider);
  return ApiClient(baseUrl: serverUrl);
});

final serverUrlProvider = StateProvider<String>((ref) => 'http://localhost:3000');

final serverInfoProvider =
    StateNotifierProvider<ServerInfoNotifier, ServerInfoState>((ref) {
  return ServerInfoNotifier(ref);
});

class ServerInfoState {
  final ServerInfo? info;
  final bool isLoading;
  final String? error;

  const ServerInfoState({this.info, this.isLoading = false, this.error});

  ServerInfoState copyWith({ServerInfo? info, bool? isLoading, String? error}) {
    return ServerInfoState(
      info: info ?? this.info,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ServerInfoNotifier extends StateNotifier<ServerInfoState> {
  final Ref _ref;

  ServerInfoNotifier(this._ref) : super(const ServerInfoState());

  Future<bool> connect(String serverUrl) async {
    _ref.read(serverUrlProvider.notifier).state = serverUrl;
    state = const ServerInfoState(isLoading: true);
    try {
      final api = _ref.read(apiClientProvider);
      final info = await api.getServerInfo();
      state = ServerInfoState(info: info);
      return true;
    } catch (e) {
      state = ServerInfoState(error: _extractError(e));
      return false;
    }
  }

  void reset() {
    state = const ServerInfoState();
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        return 'Could not reach server';
      }
      return msg.replaceFirst('Exception: ', '');
    }
    return 'Connection failed';
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthState {
  final String? token;
  final String? userId;
  final String? displayName;
  final bool isGuest;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.token,
    this.userId,
    this.displayName,
    this.isGuest = false,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null;

  AuthState copyWith({
    String? token,
    String? userId,
    String? displayName,
    bool? isGuest,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState());

  Future<bool> guestLogin(String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = _ref.read(apiClientProvider);
      final token = await api.guestLogin(displayName);
      final payload = _decodeJwt(token);
      state = AuthState(
        token: token,
        userId: payload['userId'],
        displayName: payload['displayName'] ?? displayName,
        isGuest: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<bool> register(
      String username, String password, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = _ref.read(apiClientProvider);
      final token = await api.register(username, password, displayName);
      final payload = _decodeJwt(token);
      state = AuthState(
        token: token,
        userId: payload['userId'],
        displayName: payload['displayName'],
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = _ref.read(apiClientProvider);
      final token = await api.login(username, password);
      final payload = _decodeJwt(token);
      state = AuthState(
        token: token,
        userId: payload['userId'],
        displayName: payload['displayName'],
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  void logout() {
    _ref.read(apiClientProvider).setToken(null);
    state = const AuthState();
  }

  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded);
  }

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data is Map) {
      final data = e.response!.data as Map;
      if (data.containsKey('error')) {
        return data['error'].toString();
      }
    }
    if (e is DioException) {
      return e.message ?? 'Request failed';
    }
    return 'An error occurred';
  }
}
