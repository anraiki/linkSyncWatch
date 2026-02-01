import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/download/download_service.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressNotifier, Map<String, DownloadProgress>>((ref) {
  return DownloadProgressNotifier(ref);
});

class DownloadProgressNotifier
    extends StateNotifier<Map<String, DownloadProgress>> {
  final Ref _ref;
  late final StreamSubscription? _sub;

  DownloadProgressNotifier(this._ref) : super({}) {
    final service = _ref.read(downloadServiceProvider);
    service.onProgress = (progress) {
      state = {...state, progress.mediaId: progress};
    };
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
