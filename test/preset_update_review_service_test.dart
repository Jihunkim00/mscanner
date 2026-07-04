import 'package:flutter_test/flutter_test.dart';
import 'package:mscanner/helpers/preset_update_review_service.dart';
import 'package:mscanner/helpers/settings_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PresetUpdateReviewService', () {
    test('shows review once after an app update with saved preset settings',
        () async {
      SharedPreferences.setMockInitialValues({
        PresetUpdateReviewService.lastSeenAppVersionKey: '1.3.34',
        SettingsHelper.selectedLanguageCodeKey: 'ko',
        SettingsHelper.selectedFoodStyleKey: SettingsHelper.foodStyleLowSalt,
        SettingsHelper.selectedMenuNumberKey: 'all',
        SettingsHelper.customPresetDescriptionKey: 'existing preset prompt',
      });

      final prefs = await SharedPreferences.getInstance();
      final decision = await PresetUpdateReviewService.evaluateLaunch(
        prefs: prefs,
        currentVersion: '1.3.35',
      );

      expect(decision.shouldShowReview, isTrue);
      expect(prefs.getString(SettingsHelper.selectedLanguageCodeKey), 'ko');
      expect(
        prefs.getString(SettingsHelper.selectedFoodStyleKey),
        SettingsHelper.foodStyleLowSalt,
      );
      expect(prefs.getString(SettingsHelper.selectedMenuNumberKey), 'all');
      expect(
        prefs.getString(SettingsHelper.customPresetDescriptionKey),
        'existing preset prompt',
      );

      await PresetUpdateReviewService.markReviewComplete(
        prefs: prefs,
        currentVersion: '1.3.35',
      );

      final nextDecision = await PresetUpdateReviewService.evaluateLaunch(
        prefs: prefs,
        currentVersion: '1.3.35',
      );

      expect(nextDecision.shouldShowReview, isFalse);
      expect(
        prefs
            .getString(PresetUpdateReviewService.lastPresetReviewAppVersionKey),
        '1.3.35',
      );
      expect(
        prefs.getString(PresetUpdateReviewService.lastSeenAppVersionKey),
        '1.3.35',
      );
    });

    test('keeps fresh install on the existing first-run flow', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      final decision = await PresetUpdateReviewService.evaluateLaunch(
        prefs: prefs,
        currentVersion: '1.3.35',
      );

      expect(decision.isFreshInstall, isTrue);
      expect(decision.shouldShowReview, isFalse);
      expect(
        prefs.getString(PresetUpdateReviewService.lastSeenAppVersionKey),
        '1.3.35',
      );
    });

    test('treats legacy installs with preset settings as update review targets',
        () async {
      SharedPreferences.setMockInitialValues({
        SettingsHelper.selectedLanguageCodeKey: 'ja',
      });

      final prefs = await SharedPreferences.getInstance();
      final decision = await PresetUpdateReviewService.evaluateLaunch(
        prefs: prefs,
        currentVersion: '1.3.35',
      );

      expect(decision.isFreshInstall, isFalse);
      expect(decision.shouldShowReview, isTrue);
    });
  });

  group('preset language fallback', () {
    const supported = ['en', 'ko', 'ja', 'pt-BR'];

    test('uses saved language when it is valid', () {
      final language = SettingsHelper.resolveSupportedLanguageCode(
        storedLanguageCode: 'ja',
        systemLocaleCode: 'ko-KR',
        supportedLanguageCodes: supported,
      );

      expect(language, 'ja');
    });

    test(
        'uses system locale language when saved language is missing or invalid',
        () {
      final language = SettingsHelper.resolveSupportedLanguageCode(
        storedLanguageCode: 'invalid',
        systemLocaleCode: 'ko-KR',
        supportedLanguageCodes: supported,
      );

      expect(language, 'ko');
    });

    test('keeps supported region locale and falls back for unsupported systems',
        () {
      final portuguese = SettingsHelper.resolveSupportedLanguageCode(
        systemLocaleCode: 'pt_BR',
        supportedLanguageCodes: supported,
      );
      final fallback = SettingsHelper.resolveSupportedLanguageCode(
        systemLocaleCode: 'nl-NL',
        supportedLanguageCodes: supported,
      );

      expect(portuguese, 'pt-BR');
      expect(fallback, 'en');
    });
  });
}
