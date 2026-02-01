import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum DownloadStatus { pending, downloading, completed, failed, cancelled }

class DownloadProgress {
  final String mediaId;
  final double progress;
  final int downloaded;
  final int total;
  final DownloadStatus status;

  DownloadProgress({
    required this.mediaId,
    required this.progress,
    required this.downloaded,
    required this.total,
    required this.status,
  });
}

class DownloadService {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DownloadProgress> _downloads = {};

  Function(DownloadProgress)? onProgress;

  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<String> getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'SyncWatch', 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
  }

  Future<String?> startDownload(
      String url, String mediaId, String filename) async {
    final mediaDir = await getMediaDirectory();
    final filePath = p.join(mediaDir, filename);
    final file = File(filePath);

    if (await file.exists()) {
      final length = await file.length();
      _updateProgress(
          mediaId,
          DownloadProgress(
            mediaId: mediaId,
            progress: 100,
            downloaded: length,
            total: length,
            status: DownloadStatus.completed,
          ));
      return filePath;
    }

    final cancelToken = CancelToken();
    _cancelTokens[mediaId] = cancelToken;

    try {
      _updateProgress(
          mediaId,
          DownloadProgress(
            mediaId: mediaId,
            progress: 0,
            downloaded: 0,
            total: 0,
            status: DownloadStatus.downloading,
          ));

      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? (received / total) * 100 : 0.0;
          _updateProgress(
              mediaId,
              DownloadProgress(
                mediaId: mediaId,
                progress: progress,
                downloaded: received,
                total: total,
                status: DownloadStatus.downloading,
              ));
        },
      );

      final length = await file.length();
      _updateProgress(
          mediaId,
          DownloadProgress(
            mediaId: mediaId,
            progress: 100,
            downloaded: length,
            total: length,
            status: DownloadStatus.completed,
          ));

      return filePath;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _updateProgress(
            mediaId,
            DownloadProgress(
              mediaId: mediaId,
              progress: 0,
              downloaded: 0,
              total: 0,
              status: DownloadStatus.cancelled,
            ));
      } else {
        _updateProgress(
            mediaId,
            DownloadProgress(
              mediaId: mediaId,
              progress: 0,
              downloaded: 0,
              total: 0,
              status: DownloadStatus.failed,
            ));
      }
      return null;
    } finally {
      _cancelTokens.remove(mediaId);
    }
  }

  void cancelDownload(String mediaId) {
    _cancelTokens[mediaId]?.cancel();
  }

  DownloadProgress? getProgress(String mediaId) => _downloads[mediaId];

  void _updateProgress(String mediaId, DownloadProgress progress) {
    _downloads[mediaId] = progress;
    onProgress?.call(progress);
  }
}
