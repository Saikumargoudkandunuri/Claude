import 'package:dio/dio.dart';

import '../domain/drawing_file.dart';

class DrawingsRepository {
  DrawingsRepository(this._dio);
  final Dio _dio;

  Future<List<DrawingFile>> listForProject(String projectId, {String? category}) async {
    final res = await _dio.get('/projects/$projectId/files',
        queryParameters: {if (category != null) 'category': category},);
    final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(DrawingFile.fromJson).toList();
  }

  /// Upload (multipart). [bytes] is the file content, [filename] its name.
  Future<DrawingFile> upload({
    required String projectId,
    required String category,
    required List<int> bytes,
    required String filename,
    String? caption,
  }) async {
    final form = FormData.fromMap({
      'category': category,
      if (caption != null) 'caption': caption,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/projects/$projectId/files', data: form);
    return DrawingFile.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String fileId) => _dio.delete('/files/$fileId');
}
