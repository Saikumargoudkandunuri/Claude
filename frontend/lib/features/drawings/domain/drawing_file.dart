/// A stored file (drawing, 3D, quotation, photo, video, voice note).
class DrawingFile {
  const DrawingFile({
    required this.id,
    required this.projectId,
    required this.category,
    required this.originalName,
    required this.downloadUrl,
    this.mimeType,
    this.sizeBytes,
    this.caption,
    this.createdAt,
  });

  final String id;
  final String projectId;
  final String category;
  final String originalName;
  final String downloadUrl;
  final String? mimeType;
  final int? sizeBytes;
  final String? caption;
  final String? createdAt;

  bool get isPdf =>
      (mimeType?.contains('pdf') ?? false) ||
      originalName.toLowerCase().endsWith('.pdf');

  bool get isImage => mimeType?.startsWith('image/') ?? false;

  factory DrawingFile.fromJson(Map<String, dynamic> j) => DrawingFile(
        id: j['id'] as String,
        projectId: j['projectId'] as String? ?? '',
        category: j['category'] as String? ?? '',
        originalName: j['originalName'] as String? ?? 'file',
        downloadUrl: j['downloadUrl'] as String? ?? '',
        mimeType: j['mimeType'] as String?,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
        caption: j['caption'] as String?,
        createdAt: j['createdAt']?.toString(),
      );
}

/// The drawing categories rendered as sections in the UI.
const kDrawingCategories = <String, String>{
  'working_drawing': 'Working Drawings',
  'measurement_drawing': 'Measurement Drawings',
  'site_drawing': 'Site Drawings',
  'pdf_drawing': 'PDF Drawings',
  '3d_design': '3D Designs',
  'quotation': 'Quotation',
};

const kMediaCategories = <String, String>{
  'photo': 'Photos',
  'video': 'Videos',
  'voice_note': 'Voice Notes',
};
