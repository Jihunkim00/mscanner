import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/services/vision_upload_service.dart';

class FakeVisionStorage implements VisionStorageGateway {
  final uploaded = <String, Uint8List>{};
  final deleted = <String>[];
  String? failurePath;

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    if (path == failurePath) throw StateError('upload failed');
    uploaded[path] = bytes;
  }

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    uploaded.remove(path);
  }
}

void main() {
  test('uploads upstream-compressed bytes unchanged with deterministic paths',
      () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('vision-upload-test-');
    try {
      final sourceImages = <File>[];
      for (var index = 0; index < 4; index++) {
        final file = File('${tempDirectory.path}/source-$index.bin');
        await file.writeAsBytes(<int>[index + 1, index + 2]);
        sourceImages.add(file);
      }

      final storage = FakeVisionStorage();
      final service = VisionUploadService(
        storage: storage,
        uidProvider: () async => 'uid-123',
      );

      final result = await service.uploadMultiScan(
        sourceImages: sourceImages,
        scanId: 'v-scan-123',
      );

      expect(result.uploadedPaths, <String>[
        'temp_scan/uid-123/v-scan-123/1.jpg',
        'temp_scan/uid-123/v-scan-123/2.jpg',
        'temp_scan/uid-123/v-scan-123/3.jpg',
        'temp_scan/uid-123/v-scan-123/4.jpg',
      ]);
      expect(result.sourceImageCount, 4);
      expect(result.perImageBytes, <int>[2, 2, 2, 2]);
      expect(result.totalBytes, 8);
      expect(storage.uploaded.keys.toList(), result.uploadedPaths);
      expect(
        storage.uploaded[result.uploadedPaths[0]],
        orderedEquals(<int>[1, 2]),
      );
      expect(
        storage.uploaded[result.uploadedPaths[1]],
        orderedEquals(<int>[2, 3]),
      );
      expect(
        storage.uploaded[result.uploadedPaths[2]],
        orderedEquals(<int>[3, 4]),
      );
      expect(
        storage.uploaded[result.uploadedPaths[3]],
        orderedEquals(<int>[4, 5]),
      );
      expect(result.imageDimensions, hasLength(4));
    } finally {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('cleans already uploaded images when a later upload fails', () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('vision-upload-test-');
    try {
      final sourceImages = <File>[];
      for (var index = 0; index < 2; index++) {
        final file = File('${tempDirectory.path}/source-$index.bin');
        await file.writeAsBytes(<int>[index]);
        sourceImages.add(file);
      }

      final storage = FakeVisionStorage()
        ..failurePath = 'temp_scan/uid-123/v-scan-failure/2.jpg';
      final service = VisionUploadService(
        storage: storage,
        uidProvider: () async => 'uid-123',
      );

      await expectLater(
        service.uploadMultiScan(
          sourceImages: sourceImages,
          scanId: 'v-scan-failure',
        ),
        throwsStateError,
      );
      expect(storage.deleted, <String>[
        'temp_scan/uid-123/v-scan-failure/1.jpg',
      ]);
      expect(storage.uploaded, isEmpty);
    } finally {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('builds and rejects temporary Storage paths safely', () {
    expect(
      VisionUploadService.buildStoragePath(
        uid: 'uid-123',
        scanId: 'v-scan-123',
        index: 1,
      ),
      'temp_scan/uid-123/v-scan-123/1.jpg',
    );
    expect(
      () => VisionUploadService.buildStoragePath(
        uid: 'uid/other',
        scanId: 'v-scan-123',
        index: 1,
      ),
      throwsArgumentError,
    );
  });
}
