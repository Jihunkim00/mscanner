// These are the installed Firebase plugins' test platform interfaces.
// ignore_for_file: depend_on_referenced_packages

import 'dart:ui' as ui;
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';
import 'package:mscanner/screens/favorite_screen.dart';
import 'package:mscanner/styles/app_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'support/app_test_fonts.dart';

class _FixtureCore extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      FirebaseAppPlatform(
          name,
          const FirebaseOptions(
              apiKey: 'fixture',
              appId: 'fixture',
              messagingSenderId: 'fixture',
              projectId: 'fixture'));
}

class _FixtureAuth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {InternalUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform get currentUser => _FixtureUser(this);
}

class _FixtureUser extends UserPlatform {
  _FixtureUser(FirebaseAuthPlatform auth)
      : super(
            auth,
            _FixtureMultiFactor(auth),
            InternalUserDetails(
                userInfo: InternalUserInfo(
                    uid: 'fixture', isAnonymous: false, isEmailVerified: false),
                providerData: []));
}

class _FixtureMultiFactor extends MultiFactorPlatform {
  _FixtureMultiFactor(super.auth);
}

class _FixtureStore extends FirebaseFirestorePlatform {
  Map<String, dynamic> data = {};
  final reads = <String>[];
  @override
  FirebaseFirestorePlatform delegateFor(
          {required FirebaseApp app, required String databaseId}) =>
      this;
  @override
  CollectionReferencePlatform collection(String path) =>
      _FixtureCollection(this, path);
  @override
  DocumentReferencePlatform doc(String path) => _FixtureDocument(this, path);
}

class _FixtureCollection extends CollectionReferencePlatform {
  _FixtureCollection(super.firestore, super.path);
  @override
  DocumentReferencePlatform doc([String? id]) => firestore.doc('$path/$id');
}

class _FixtureDocument extends DocumentReferencePlatform {
  _FixtureDocument(super.firestore, super.path);
  @override
  Future<DocumentSnapshotPlatform> get(
      [GetOptions options = const GetOptions()]) async {
    final store = firestore as _FixtureStore;
    store.reads.add(path);
    return DocumentSnapshotPlatform(store, path, store.data,
        InternalSnapshotMetadata(hasPendingWrites: false, isFromCache: false));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = _FixtureStore();
  setUpAll(() async {
    final core = FirebasePlatform.instance;
    final auth = FirebaseAuthPlatform.instance;
    final prefs = SharedPreferencesAsyncPlatform.instance;
    FirebasePlatform.instance = _FixtureCore();
    final firestore = FirebaseFirestorePlatform.instance;
    addTearDown(() {
      FirebasePlatform.instance = core;
      FirebaseAuthPlatform.instance = auth;
      FirebaseFirestorePlatform.instance = firestore;
      SharedPreferencesAsyncPlatform.instance = prefs;
    });
    FirebaseAuthPlatform.instance = _FixtureAuth();
    FirebaseFirestorePlatform.instance = store;
    await loadAppTestFonts();
  });

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store.reads.clear();
    store.data = {
      'restaurantName': 'Dahyang',
      'rating': 4,
      'review': '',
      'country': 'South Korea',
      'city': 'Seoul',
      'other': 'Jongno-gu',
      'timestamp': '2026-11-14T12:30:00',
      'responses': <String>[],
    };
  });

  Future<void> openDetail(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: const RepaintBoundary(
        key: ValueKey('favorite-detail-preview'),
        child: FavoriteScreen(documentId: 'record'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('missing photo and long editable name fit narrow enlarged text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    store.data['restaurantName'] = 'Dahyang restaurant with a very long name';
    await openDetail(tester, scale: 2);
    expect(tester.takeException(), isNull);
    final nameField = find.byType(TextField).first;
    expect(tester.widget<TextField>(nameField).style!.color, Colors.white);
    expect(store.reads, ['user_rating/fixture/data/record']);
    await tester.enterText(nameField, 'Edited restaurant');
    await tester.pump();
    expect(tester.widget<TextField>(nameField).controller!.text,
        'Edited restaurant');
    final photo =
        find.ancestor(of: nameField, matching: find.byType(Container)).first;
    expect(tester.getSize(photo).height, 350);
    expect(find.byIcon(CupertinoIcons.star_fill), findsNWidgets(4));
    expect(find.byIcon(CupertinoIcons.star), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo overlay shows the white name without an input background',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const imageUrl = 'https://fixture.invalid/food.jpg';
    // Seed the image cache with a bundled fixture; no HTTP or live Firebase.
    final image = await tester.runAsync(() async {
      final bytes = await rootBundle.load('assets/images/tutorial_sample.jpg');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
    PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage(imageUrl),
        () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image!))));
    addTearDown(PaintingBinding.instance.imageCache.clear);
    store.data['image_url'] = imageUrl;
    await openDetail(tester);
    expect(tester.takeException(), isNull);
    final nameField = find.byType(TextField).first;
    final photo =
        find.ancestor(of: nameField, matching: find.byType(Container)).first;
    expect(tester.getSize(photo).height, 422);
    await expectLater(find.byKey(const ValueKey('favorite-detail-preview')),
        matchesGoldenFile('goldens/favorite_photo_overlay.png'));
  });
}
