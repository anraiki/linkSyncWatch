import 'package:dio/dio.dart';

class ServerInfo {
  final String name;
  final bool registrationEnabled;
  final bool guestEnabled;

  const ServerInfo({
    this.name = 'dSync Server',
    this.registrationEnabled = false,
    this.guestEnabled = true,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      name: json['name'] ?? 'dSync Server',
      registrationEnabled: json['registrationEnabled'] ?? false,
      guestEnabled: json['guestEnabled'] ?? true,
    );
  }
}

class ApiClient {
  late final Dio _dio;
  String? _token;

  String get baseUrl => _dio.options.baseUrl;

  ApiClient({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: false,
    ));
  }

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  // Server info
  Future<ServerInfo> getServerInfo() async {
    final response = await _dio.get('/api/server/info');
    return ServerInfo.fromJson(Map<String, dynamic>.from(response.data));
  }

  // Auth — guest
  Future<String> guestLogin(String displayName) async {
    final response = await _dio.post('/auth/guest', data: {
      'displayName': displayName,
    });
    final token = response.data['token'] as String;
    _token = token;
    return token;
  }

  // Auth
  Future<String> register(
      String username, String password, String displayName) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'password': password,
      'displayName': displayName,
    });
    final token = response.data['token'] as String;
    _token = token;
    return token;
  }

  Future<String> login(String username, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    final token = response.data['token'] as String;
    _token = token;
    return token;
  }

  // Rooms
  Future<List<Map<String, dynamic>>> getRooms() async {
    final response = await _dio.get('/api/rooms');
    return List<Map<String, dynamic>>.from(response.data['rooms'] ?? []);
  }

  Future<Map<String, dynamic>> createRoom(String name,
      {int capacity = 10, bool isPublic = true}) async {
    final response = await _dio.post('/api/rooms', data: {
      'name': name,
      'capacity': capacity,
      'isPublic': isPublic,
    });
    return Map<String, dynamic>.from(response.data['room']);
  }

  Future<Map<String, dynamic>> getRoom(String roomId) async {
    final response = await _dio.get('/api/rooms/$roomId');
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> deleteRoom(String roomId) async {
    await _dio.delete('/api/rooms/$roomId');
  }

  // Media
  Future<Map<String, dynamic>> addMediaUrl(
      String roomId, String url, String filename) async {
    final response =
        await _dio.post('/api/rooms/$roomId/media/url', data: {
      'url': url,
      'filename': filename,
    });
    return Map<String, dynamic>.from(response.data['media']);
  }

  Future<void> removeMedia(String roomId, String mediaId) async {
    await _dio.delete('/api/rooms/$roomId/media/$mediaId');
  }

  String getMediaDownloadUrl(String mediaId) {
    return '${_dio.options.baseUrl}/api/media/$mediaId/download';
  }
}
