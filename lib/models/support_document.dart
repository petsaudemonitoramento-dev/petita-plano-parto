class SupportDocument {
  const SupportDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.status,
    required this.chunkCount,
    required this.totalChunks,
    required this.embeddedChunks,
    required this.createdAt,
    this.processingError,
    this.processedAt,
  });

  final String id;
  final String title;
  final String category;
  final String fileName;
  final String filePath;
  final String mimeType;
  final int sizeBytes;
  final String status;
  final int chunkCount;
  final int totalChunks;
  final int embeddedChunks;
  final String? processingError;
  final DateTime createdAt;
  final DateTime? processedAt;

  bool get isProcessing => status == 'queued' || status == 'processing';
  bool get isAvailable => status == 'available';
  bool get hasError => status == 'error';

  String get formattedSize {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$sizeBytes bytes';
  }

  factory SupportDocument.fromJson(Map<String, dynamic> json) {
    return SupportDocument(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Outros',
      fileName: json['file_name'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'queued',
      chunkCount: (json['chunk_count'] as num?)?.toInt() ?? 0,
      totalChunks: (json['total_chunks'] as num?)?.toInt() ?? 0,
      embeddedChunks: (json['embedded_chunks'] as num?)?.toInt() ?? 0,
      processingError: json['processing_error'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      processedAt: DateTime.tryParse(json['processed_at']?.toString() ?? ''),
    );
  }
}

class SupportStorageUsage {
  const SupportStorageUsage({
    required this.usedBytes,
    required this.maxBytes,
  });

  final int usedBytes;
  final int maxBytes;

  double get fraction => maxBytes <= 0 ? 0 : (usedBytes / maxBytes).clamp(0, 1).toDouble();
  int get remainingBytes => (maxBytes - usedBytes).clamp(0, maxBytes).toInt();

  String get usedLabel => _format(usedBytes);
  String get maxLabel => _format(maxBytes);
  String get remainingLabel => _format(remainingBytes);

  static String _format(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory SupportStorageUsage.fromJson(Map<String, dynamic> json) {
    return SupportStorageUsage(
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      maxBytes: (json['max_bytes'] as num?)?.toInt() ?? 943718400,
    );
  }
}
