import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

typedef VisionUidProvider = Future<String?> Function();

class VisionImageDimensions {
  const VisionImageDimensions(this.width, this.height);

  final int width;
  final int height;

  @override
  String toString() => '${width}x$height';
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
    required this.imageDimensions,
  });

  final String scanId;
  final int sourceImageCount;
  final List<String> uploadedPaths;
  final List<int> perImageBytes;
  final int totalBytes;
  final List<VisionImageDimensions?> imageDimensions;
}

class _VisionUploadTaskResult {
  const _VisionUploadTaskResult.success({
    required this.index,
    required this.path,
    required this.bytes,
    required this.latencyMs,
  })  : succeeded = true,
        error = null,
        stackTrace = null;

  const _VisionUploadTaskResult.failure({
    required this.index,
    required this.path,
    required this.bytes,
    required this.latencyMs,
    required this.error,
    required this.stackTrace,
  }) : succeeded = false;

  final int index;
  final String path;
  final int bytes;
  final int latencyMs;
  final bool succeeded;
  final Object? error;
  final StackTrace? stackTrace;
}

class VisionUploadService {
  VisionUploadService({
    VisionStorageGateway? storage,
    VisionUidProvider? uidProvider,
  })  : _storage = storage ?? FirebaseVisionStorageGateway(),
        _uidProvider = uidProvider ?? _resolveAuthenticatedUid;

  static const int maxImageCount = 4;
  static final RegExp _safePathSegment = RegExp(r'^[A-Za-z0-9._:-]{1,64}$');

  static bool _isSafePathSegment(String value) {
    return value != '.' && value != '..' && _safePathSegment.hasMatch(value);
  }

  final VisionStorageGateway _storage;
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

    final inputBytes = await Future.wait(
      sourceImages.map((sourceImage) => sourceImage.readAsBytes()),
    );
    final totalInputBytes =
        inputBytes.fold<int>(0, (sum, bytes) => sum + bytes.length);
    final imageDimensions = inputBytes.map(_decodeDimensions).toList();
    debugPrint('[VisionUpload] transport=storage_paths');
    debugPrint('[VisionUpload] sourceImageCount=${sourceImages.length}');
    debugPrint(
      '[VisionUpload] totalInputBytes=$totalInputBytes',
    );
    for (var index = 0; index < inputBytes.length; index++) {
      debugPrint(
        '[VisionUpload] image=${index + 1} '
        'dimensions=${imageDimensions[index] ?? 'unknown'} '
        'bytes=${inputBytes[index].length}',
      );
    }
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
    debugPrint('[VisionUpload] upload_start');

    final uploadResults = await Future.wait(
      List<_VisionUploadTaskResult>.generate(
        inputBytes.length,
        (index) => _uploadOne(
          index: index,
          path: paths[index],
          bytes: inputBytes[index],
        ),
      ),
    );
    final failedUploads =
        uploadResults.where((result) => !result.succeeded).toList();
    if (failedUploads.isNotEmpty) {
      final successfulPaths = uploadResults
          .where((result) => result.succeeded)
          .map((result) => result.path)
          .toList();
      await _bestEffortDelete(successfulPaths);
      final firstFailure = failedUploads.first;
      debugPrint(
        '[VisionUpload] upload_failed count=${failedUploads.length} '
        'firstIndex=${firstFailure.index + 1}',
      );
      final error = firstFailure.error;
      final stackTrace = firstFailure.stackTrace;
      if (error != null && stackTrace != null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      throw StateError('Vision image upload failed');
    }

    final perImageBytes = inputBytes.map((bytes) => bytes.length).toList();
    final totalBytes = totalInputBytes;
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
      imageDimensions: List.unmodifiable(imageDimensions),
    );
  }

  Future<_VisionUploadTaskResult> _uploadOne({
    required int index,
    required String path,
    required Uint8List bytes,
  }) async {
    final startedAt = DateTime.now();
    try {
      await _storage.upload(path, bytes);
      final latencyMs = DateTime.now().difference(startedAt).inMilliseconds;
      debugPrint(
        '[VisionUpload] upload_image index=${index + 1} '
        'bytes=${bytes.length} latencyMs=$latencyMs status=success',
      );
      return _VisionUploadTaskResult.success(
        index: index,
        path: path,
        bytes: bytes.length,
        latencyMs: latencyMs,
      );
    } catch (error, stackTrace) {
      final latencyMs = DateTime.now().difference(startedAt).inMilliseconds;
      debugPrint(
        '[VisionUpload] upload_image index=${index + 1} '
        'bytes=${bytes.length} latencyMs=$latencyMs '
        'status=failure reason=${error.runtimeType}',
      );
      return _VisionUploadTaskResult.failure(
        index: index,
        path: path,
        bytes: bytes.length,
        latencyMs: latencyMs,
        error: error,
        stackTrace: stackTrace,
      );
    }
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
