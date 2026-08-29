import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

const int visionUploadLongEdge = 1800;
const int visionUploadJpegQuality = 80;

typedef VisionImageCompressor = Future<Uint8List> Function(Uint8List bytes);
typedef VisionUidProvider = Future<String?> Function();

class VisionImageDimensions {
  const VisionImageDimensions(this.width, this.height);

  final int width;
  final int height;

  @override
  String toString() => '${width}x$height';
}

class VisionPreparedImage {
  const VisionPreparedImage({
    required this.bytes,
    this.originalDimensions,
    this.resizedDimensions,
  });

  final Uint8List bytes;
  final VisionImageDimensions? originalDimensions;
  final VisionImageDimensions? resizedDimensions;
}

class VisionImageProcessor {
  VisionImageProcessor({VisionImageCompressor? compressor})
      : _compressor = compressor ?? _compressWithVisionPolicy;

  final VisionImageCompressor _compressor;

  Future<VisionPreparedImage> prepare(Uint8List bytes) async {
    final compressed = await _compressor(bytes);
    return VisionPreparedImage(
      bytes: compressed,
      originalDimensions: _decodeDimensions(bytes),
      resizedDimensions: _decodeDimensions(compressed),
    );
  }

  static Future<Uint8List> _compressWithVisionPolicy(Uint8List bytes) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: visionUploadLongEdge,
      minHeight: visionUploadLongEdge,
      quality: visionUploadJpegQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (compressed.isEmpty) {
      throw StateError('Vision image compression returned empty data');
    }
    return compressed;
  }

  static VisionImageDimensions? _decodeDimensions(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return VisionImageDimensions(decoded.width, decoded.height);
    } catch (_) {
      return null;
    }
  }
}

abstract interface class VisionStorageGateway {
  Future<void> upload(String path, Uint8List bytes);

  Future<void> delete(String path);
}

class FirebaseVisionStorageGateway implements VisionStorageGateway {
  FirebaseVisionStorageGateway({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<void> upload(String path, Uint8List bytes) {
    return _storage.ref(path).putData(
          bytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'no-store',
          ),
        );
  }

  @override
  Future<void> delete(String path) => _storage.ref(path).delete();
}

class VisionUploadResult {
  const VisionUploadResult({
    required this.scanId,
    required this.sourceImageCount,
    required this.uploadedPaths,
    required this.perImageBytes,
    required this.totalBytes,
    required this.originalDimensions,
    required this.resizedDimensions,
  });

  final String scanId;
  final int sourceImageCount;
  final List<String> uploadedPaths;
  final List<int> perImageBytes;
  final int totalBytes;
  final List<VisionImageDimensions?> originalDimensions;
  final List<VisionImageDimensions?> resizedDimensions;
}

class VisionUploadService {
  VisionUploadService({
    VisionStorageGateway? storage,
    VisionImageProcessor? imageProcessor,
    VisionUidProvider? uidProvider,
  })  : _storage = storage ?? FirebaseVisionStorageGateway(),
        _imageProcessor = imageProcessor ?? VisionImageProcessor(),
        _uidProvider = uidProvider ?? _resolveAuthenticatedUid;

  static const int maxImageCount = 4;
  static final RegExp _safePathSegment = RegExp(r'^[A-Za-z0-9._:-]{1,64}$');

  static bool _isSafePathSegment(String value) {
    return value != '.' && value != '..' && _safePathSegment.hasMatch(value);
  }

  final VisionStorageGateway _storage;
  final VisionImageProcessor _imageProcessor;
  final VisionUidProvider _uidProvider;

  Future<VisionUploadResult> uploadMultiScan({
    required List<File> sourceImages,
    required String scanId,
  }) async {
    if (sourceImages.length < 2 || sourceImages.length > maxImageCount) {
      throw ArgumentError(
        'Vision multi upload requires 2-$maxImageCount source images',
      );
    }
    if (!_isSafePathSegment(scanId)) {
      throw ArgumentError('Invalid Vision scan id');
    }

    final uid = await _uidProvider();
    if (uid == null || !_isSafePathSegment(uid)) {
      throw StateError('Authenticated user required for Vision upload');
    }

    final compressionStartedAt = DateTime.now();
    debugPrint('[VisionUpload] compress_start');
    final prepared = await Future.wait(
      sourceImages.map((sourceImage) async {
        final bytes = await sourceImage.readAsBytes();
        return _imageProcessor.prepare(bytes);
      }),
    );
    debugPrint(
      '[VisionUpload] compress_complete '
      'latencyMs=${DateTime.now().difference(compressionStartedAt).inMilliseconds}',
    );
    final paths = List<String>.generate(
      sourceImages.length,
      (index) => buildStoragePath(
        uid: uid,
        scanId: scanId,
        index: index + 1,
      ),
    );

    final uploadStartedAt = DateTime.now();
    debugPrint('[VisionUpload] scanId=$scanId');
    debugPrint('[VisionUpload] sourceImageCount=${sourceImages.length}');
    for (var index = 0; index < prepared.length; index++) {
      final item = prepared[index];
      debugPrint(
        '[VisionUpload] image=${index + 1} '
        'original=${item.originalDimensions ?? 'unknown'} '
        'resized=${item.resizedDimensions ?? 'unknown'} '
        'compressedBytes=${item.bytes.length}',
      );
    }
    debugPrint('[VisionUpload] upload_start');

    final uploadedPaths = <String>[];
    try {
      for (var index = 0; index < prepared.length; index++) {
        await _storage.upload(paths[index], prepared[index].bytes);
        uploadedPaths.add(paths[index]);
      }
    } catch (error) {
      await _bestEffortDelete(uploadedPaths);
      debugPrint('[VisionUpload] upload_failed reason=${error.runtimeType}');
      rethrow;
    }

    final perImageBytes = prepared.map((item) => item.bytes.length).toList();
    final totalBytes = perImageBytes.fold<int>(0, (sum, value) => sum + value);
    debugPrint(
      '[VisionUpload] upload_complete totalBytes=$totalBytes '
      'latencyMs=${DateTime.now().difference(uploadStartedAt).inMilliseconds}',
    );
    debugPrint('[VisionUpload] path_mode=storage_paths');

    return VisionUploadResult(
      scanId: scanId,
      sourceImageCount: sourceImages.length,
      uploadedPaths: List.unmodifiable(paths),
      perImageBytes: List.unmodifiable(perImageBytes),
      totalBytes: totalBytes,
      originalDimensions: List.unmodifiable(
        prepared.map((item) => item.originalDimensions),
      ),
      resizedDimensions: List.unmodifiable(
        prepared.map((item) => item.resizedDimensions),
      ),
    );
  }

  static String buildStoragePath({
    required String uid,
    required String scanId,
    required int index,
  }) {
    if (!_isSafePathSegment(uid) ||
        !_isSafePathSegment(scanId) ||
        index < 1 ||
        index > maxImageCount) {
      throw ArgumentError('Invalid Vision temporary storage path');
    }
    return 'temp_scan/$uid/$scanId/$index.jpg';
  }

  static Future<String?> _resolveAuthenticatedUid() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await FirebaseAuth.instance.signInAnonymously();
      user = FirebaseAuth.instance.currentUser;
    }
    return user?.uid;
  }

  Future<void> _bestEffortDelete(List<String> paths) async {
    for (final path in paths) {
      try {
        await _storage.delete(path);
      } catch (error) {
        debugPrint(
          '[VisionUpload] cleanup_warning path=$path reason=${error.runtimeType}',
        );
      }
    }
  }
}
