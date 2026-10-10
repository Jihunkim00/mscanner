# PR18: 창 크기와 접힘 경계에 맞춘 화면 및 iOS scene 이전

접기·펼치기와 회전으로 앱 창이 바뀌어도 촬영/분석을 다시 시작하지 않고, 사용 중인 사진·입력·결과와 스크롤을 유지하도록 개선했다. 기존에는 시작 시 작은 화면을 세로로 고정했고, 결과 화면은 한 열이었으며 홈 배너는 최초 창 너비로만 로드했다.

좁은 창은 기존 세로 결과 흐름을 유지한다. 충분한 너비와 높이가 있으면 원본 이미지와 번역·음식 설명·환산 가격을 좌우 패널로 표시한다. 플랫폼이 세로/가로 접힘 경계를 제공하면 좌우/상하로 나누고, 영역이 부족하면 안전한 한 영역에서 스크롤한다. Flip의 펼친 상태와 접힘 정보가 없는 창도 현재 제약으로 배치한다.

## 주요 변경

- 전역 방향 고정을 해제하고 OS 설정을 따른다. LayoutBuilder와 현재 MediaQuery, SafeArea, 키보드 및 textScaler를 사용한다.
- 결과 패널 내부 State, 리뷰, 선택 사진/메뉴 및 양쪽 스크롤 위치를 유지한다. 분석 요청과 응답 스트림은 기존 화면 State에 남아 있다.
- 원본 이미지 확대와 멀티 이미지 선택을 유지한다. 공유는 viewport 밖의 내용까지 두 패널의 전체 bitmap을 합성해 담는다.
- 로딩 문구 타이머와 picker 호출이 리사이즈로 다시 시작되지 않게 한다. dispose 이후의 picker/광고 응답을 차단한다.
- 배너를 실제 콘텐츠 너비와 방향에 맞춰 재로딩한다. 400ms debounce 및 요청 세대 번호를 적용한다. 기존 프리미엄/광고 제거 조건과 전면광고 정책을 유지한다.
- 온보딩·로그인·설정·프리셋·구독과 전체 메뉴/주문 시트를 작은 창에서 스크롤할 수 있도록 보완한다.
- 기본 FlutterSceneDelegate와 기존 Main.storyboard를 연결한다. 플러그인 등록을 implicit engine callback으로 이동하고 Google Maps 초기화를 유지한다.
- Android MainActivity에 resizeableActivity=true를 명시한다. 기존 configChanges, compileSdk / targetSdk 36, 권한·로그인·광고·지도·FileProvider를 유지한다.
- 확인된 scene 호환성 문제에 한해 google_sign_in_ios 6.3.4, image_picker_ios 0.8.13+5를 고정한다. 기존 Firebase native SDK의 iOS 15 요구사항에 루트 Xcode/CocoaPods 설정을 맞춘다.

Vision V3 기본 설정, analyzeVisionV3 / gpt-6-luna 선택, 요청 payload, 구독 권한, 다국어 문구 및 Firebase 데이터 계약은 변경하지 않았다.

## 변경 파일

| 범위 | 파일 |
| --- | --- |
| 공통 배치 / 광고 / 공유 | lib/widgets/adaptive_window.dart, adaptive_scan_panels.dart, adaptive_banner.dart |
| 방향 / 온보딩 | lib/main.dart |
| 주요 화면 | lib/screens/Home_Screen.dart, Camera_Screen.dart, Loading_Screen.dart, result_screen.dart |
| 폼과 팝업 | lib/screens/Login_Screen.dart, Setting_Screen.dart, signup_screen.dart, preset_selection_screen.dart |
| 관련 위젯 | photo_capture_widget.dart, image_grid_viewer.dart, premium_ad_overlay.dart, test_purchase_widget.dart, order_phrase_bottom_sheet.dart |
| Git에 포함된 iOS 설정 | ios/Runner/Info.plist, ios/Runner.xcodeproj/project.pbxproj, ios/Podfile, ios/Flutter/AppFrameworkInfo.plist, Debug.xcconfig, Release.xcconfig |
| iOS 구현 호환성 | pubspec.yaml, pub get으로 재생성된 .flutter-plugins-dependencies |
| 회귀 검증 | test/adaptive_*_test.dart (6개 파일, 새 테스트 17개) |
| 재현 안내 | docs/pr18-native-migration.md |

## 검증 결과

2026-10-09, Windows / Flutter 3.44.7 stable / Dart 3.12.2에서 검증했다.

- 변경 전 테스트 107개 → 변경 후 **124개 모두 통과**.
- 변경한 Dart 파일 포맷 완료.
- flutter analyze: **error / warning 없음**. 기존 file_names info 2개만 남아 exit code는 1이다. 기존 배너 API 폐기 info는 해결했다.
- Android debug APK 빌드 성공: build/app/outputs/flutter-apk/app-debug.apk. 기존 Kotlin 이행 안내가 출력되며 Android 설정 변경은 추가하지 않았다.
- 로컬 plist/XML 구성과 단일 플러그인 등록, 기존 Info.plist 민감 값 보존 정적 확인.

새 테스트는 같은 위젯에서 좁음→넓음→낮은 가로→분할 창→세로/가로 접힘→좁음 전환을 연속 수행한다. 실제 LoadingScreen의 분석 1회, picker 1회 및 앱 복귀, 리뷰/선택/양쪽 스크롤 보존, 광고의 debounce·늦은 콜백·dispose·구독 시 제거, 멀티 사진 선택, RTL/글자 확대/키보드에서 버튼 접근, 화면 밖 결과의 공유 bitmap 포함을 검증한다. 실제 네트워크 분석·광고·결제·촬영 요청에는 테스트 대역을 사용했다.

## 로컬 네이티브 적용과 남은 플랫폼 검증

Git에서 제외된 **AppDelegate.swift와 AndroidManifest.xml은 로컬에 적용 완료**했다. 실제 키는 추가하지 않았다. 다른 Mac/작업 환경에는 [네이티브 적용 안내](pr18-native-migration.md)에 따라 기존 로컬 파일의 키를 보존하며 동일한 수정을 적용해야 한다.

Windows에서 iOS 빌드, Xcode simulator, iPhone Duo / Fold / Flip 실기기 전환, 실제 로그인·지도·광고·구매/복원은 실행하지 못했다. 해당 절차와 명령은 적용 안내에 정리했다.

Xcode 27 빌드의 lipo verification 오류는 Flutter 3.44.8에서 수정되었으므로 Mac에서는 **최소 3.44.8 patch**로 빌드하고 Android 회귀도 수행해야 한다. Windows의 공유 Flutter 3.44.7 SDK는 변경하지 않았다. [공식 Flutter 변경 기록](https://github.com/flutter/flutter/blob/master/CHANGELOG.md)에 근거하며 실제 Mac 빌드 성공은 아직 확인하지 않았다.
