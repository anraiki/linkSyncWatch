class MediaSource {
  final String type; // "server" | "external"
  final String? path;
  final String? url;

  const MediaSource({
    required this.type,
    this.path,
    this.url,
  });

  factory MediaSource.fromJson(Map<String, dynamic> json) {
    return MediaSource(
      type: json['type'] ?? 'external',
      path: json['path'],
      url: json['url'],
    );
  }
}

class Media {
  final String id;
  final String filename;
  final int size;
  final double duration;
  final MediaSource source;

  const Media({
    required this.id,
    required this.filename,
    this.size = 0,
    this.duration = 0,
    required this.source,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'] ?? '',
      filename: json['filename'] ?? '',
      size: json['size'] ?? 0,
      duration: (json['duration'] ?? 0).toDouble(),
      source: json['source'] != null
          ? MediaSource.fromJson(json['source'])
          : const MediaSource(type: 'external'),
    );
  }

  String getDownloadUrl(String serverUrl) {
    if (source.type == 'external' && source.url != null) {
      return source.url!;
    }
    return '$serverUrl/api/media/$id/download';
  }
}
