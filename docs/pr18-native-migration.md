# PR18 네이티브 적용 및 검증

작업 브랜치: `agent/pr18-ios27-foldable-adaptive-ui`

기준 브랜치: `agent/pr17-vision-v3-gpt6-luna-beta`

Windows 검증 환경: Flutter 3.44.7 stable / Dart 3.12.2, Android compileSdk / targetSdk 36.

작성일: 2026-10-09 (Asia/Seoul).

## Git에 포함되는 설정과 로컬 설정

`ios/Runner/AppDelegate.swift`와 `android/app/src/main/AndroidManifest.xml`은 기존 .gitignore에 따라 로컬에서 수정했다. 다른 환경에서는 **기존 로컬 파일에 아래 변경을 직접 적용해야 한다.** 두 파일을 강제로 Git에 추가하지 않는다.

`Info.plist`, Xcode 프로젝트, Flutter xcconfig, 루트 `ios/Podfile`은 PR에 포함된다. 기존 Firebase 구성 파일, .env, 서명 파일, Google Maps 키, 광고 ID, 로그인 URL scheme은 각 환경의 기존 값을 사용한다. 이 문서는 실제 키 값을 포함하지 않는다.

로컬 프로젝트 및 상위 D:\\ 경로에서 AGENTS.md를 검색했으나 해당 지침 파일은 없었다. 기존 Git 추적 파일인 .flutter-plugins-dependencies는 pub get으로 재생성되었으며 Mac에서도 pub get을 실행해 해당 환경의 플러그인 경로를 생성한다.

## 1. AppDelegate와 단일 Flutter 엔진

현재 루트 프로젝트는 `ios/Runner/Base.lproj/Main.storyboard`의 initial view controller가 `FlutterViewController`이며, Main.storyboard가 Runner의 Resources에 연결되어 있다. 기존 AppDelegate에는 별도의 엔진 생성이나 URL callback override가 없다.

[Flutter 공식 UIScene 이전 지침](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)에 따라 다음을 적용한다.

1. `@UIApplicationMain`을 `@main`으로 변경한다.
2. 클래스 선언에 `FlutterImplicitEngineDelegate`를 추가한다.
3. 기존 `application(_:didFinishLaunchingWithOptions:)`의 **Google Maps 초기화 행과 그 키를 그대로 유지**하고 super 호출을 유지한다.
4. 그 메서드의 `GeneratedPluginRegistrant.register(with: self)`를 제거한다.
5. 클래스 내부에 다음 메서드를 한 번 추가한다.

```swift
func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
  GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
}
```

`GeneratedPluginRegistrant.register` 호출은 이 메서드 한 곳에만 둔다. FlutterSceneDelegate가 storyboard의 FlutterViewController와 implicit engine을 연결한다. 별도 FlutterEngine, UIWindow, FlutterViewController 생성 코드를 추가하지 않는다.

이 프로젝트에는 기본 `FlutterSceneDelegate`가 충분하므로 새 SceneDelegate.swift나 Xcode Sources 항목을 추가하지 않았다.

## 2. Info.plist와 Xcode

PR의 Info.plist에는 다음 scene 구성이 들어 있다. 로컬 plist를 따로 관리한다면 같은 값을 병합한다.

| 키 | 값 |
| --- | --- |
| UIApplicationSceneManifest / UIApplicationSupportsMultipleScenes | false |
| UISceneConfigurations / UIWindowSceneSessionRoleApplication | 아래 scene dictionary를 담은 array |
| UISceneClassName | UIWindowScene |
| UISceneDelegateClassName | FlutterSceneDelegate |
| UISceneConfigurationName | flutter |
| UISceneStoryboardFile | Main |

단일 scene을 유지하며 현재 앱 창의 회전·크기 변경에 대응한다. 기존 LaunchScreen 및 Main.storyboard 리소스 연결을 유지한다.

- iPhone: portrait, landscape left, landscape right.
- iPad: portrait, portrait upside down, landscape left, landscape right.
- Dart 시작 시 `SystemChrome.setPreferredOrientations([])`로 OS 방향 설정을 따른다.
- Info.plist의 DTPlatformName, DTPlatformVersion, DTSDKName, DTSDKBuild, DTXcode, DTXcodeBuild, BuildMachineOSBuild, CFBundleSupportedPlatforms 및 UIDeviceFamily 수동 값을 제거했다. 플랫폼·기기 family 정보는 Xcode 설정에서 생성한다.
- 기존 Xcode TARGETED_DEVICE_FAMILY `1,2`를 유지했다.
- bundle/version, 권한 안내, 광고·SKAdNetwork 및 로그인 URL 설정은 유지했다.

현재 Firebase native dependency가 iOS 15.0을 요구하지만 루트 Xcode 및 AppFrameworkInfo.plist에는 12.0이 남아 있었다. 프로젝트의 Debug / Profile / Release와 AppFrameworkInfo.plist를 **15.0**으로 맞췄다.

루트 `ios/Podfile`과 Pods xcconfig include가 없었다. `ios/ios/Podfile`은 이전 중첩 프로젝트에 속하며 루트 Runner의 Podfile로 사용되지 않는다. 루트에 Flutter의 CocoaPods 템플릿을 기반으로 iOS 15.0 및 static framework 설정을 추가하고, Debug.xcconfig / Release.xcconfig에 해당 Pods include를 연결했다. 기존 중첩 프로젝트는 수정하지 않았다. Mac에서는 루트 `ios/Runner.xcworkspace`를 사용한다.

## 3. 확인된 iOS 플러그인 호환성 변경

전체 dependency upgrade를 수행하지 않았다. 아래 iOS 구현만 pubspec에서 고정했다.

| 플러그인 | 변경 | 근거 |
| --- | --- | --- |
| google_sign_in_ios | 6.2.5 → 6.3.4 | 6.3.0에 scene 호환성 추가, 6.3.4에서 scene URL 처리 결과 반환 수정 및 Swift CocoaPods header 제공 |
| image_picker_ios | 0.8.13+3 → 0.8.13+5 | +4의 scene view provider 수정과 +5의 카메라 확인 버튼 dismiss 중 탭 전달 수정 |

[Google Sign-In 변경 기록](https://pub.dev/packages/google_sign_in_ios/changelog), [image_picker 변경 기록](https://pub.dev/packages/image_picker_ios/changelog)에 근거한다. 기존 Google Sign-In Dart API, 서버 client ID, Firebase 인증 계약은 유지한다. 카메라 호출은 기존 image_picker 시스템 카메라이다.

로그인 플러그인은 registrar의 view controller와 scene URL callback을 사용하도록 바뀐다. 카메라 플러그인도 scene에 속한 registrar view controller를 사용한다. 기존 Maps / Mobile Ads / StoreKit 플러그인은 유지했으며 **새 scene에서의 실제 표시·복귀·구매 및 복원 검증은 Mac/실기기에서 수행해야 한다.** Native plugin registration은 implicit engine 초기화 후 한 번만 실행된다.

## 4. AndroidManifest.xml

기존 `.MainActivity`에 다음 속성을 추가한다.

```xml
android:resizeableActivity="true"
```

다음 기존 configChanges를 유지한다.

```text
orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode
```

현재 screenOrientation, min/max aspect ratio, 멀티윈도우 opt-out 제한은 없다. launchMode singleTop, taskAffinity, adjustResize, 권한, 광고·지도 metadata, Facebook 설정, Flutter embedding 및 FileProvider를 유지한다. compileSdk / targetSdk는 36 그대로이다. Android SDK / Gradle / Billing dependency를 변경하지 않았다.

[Android 방향·비율·resizability 지침](https://developer.android.com/develop/adaptive-apps/guides/app-orientation-aspect-ratio-resizability)을 따른다. APK 빌드에는 기존 AGP/Kotlin 이행 안내가 출력되지만 빌드는 성공했다.

## 5. 공통 레이아웃과 상태

- 실제 LayoutBuilder 제약과 MediaQuery의 앱 창 크기, SafeArea, 키보드, textScaler로 배치한다.
- 일반 결과 화면은 한 스크롤 흐름이다. 넓고 높이가 충분한 창은 이미지와 결과를 각각 스크롤하는 두 패널을 사용한다.
- 두 패널 콘텐츠 최소 너비는 280 / 360 logical pixels이며 패딩과 글자 확대를 추가로 반영한다. 접힘 정보가 없는 전체 콘텐츠 최대 너비는 1440이다.
- 플랫폼의 obstructing display feature는 좌우 또는 상하 영역으로 분리한다. 영역이 부족하면 가장 큰 안전한 영역에서 한 열로 표시한다. iOS의 display feature 제공을 가정하지 않는다.
- GlobalKey로 패널 내부 State를 유지하고, 제거되는 패널의 ScrollController offset을 저장·복원한다. 콘텐츠 extent가 작아지면 Flutter가 유효한 스크롤 범위로 위치를 제한할 수 있다.
- 분석은 initState와 기존 AsyncRequestGate에서 시작한다. build / 크기 변경 callback에서 분석을 시작하지 않는다. 로딩 문구 타이머도 크기 변경으로 다시 시작하지 않는다.
- 사진 선택 위젯은 한 State에서 picker를 한 번 호출한다. dispose 후 도착한 picker 결과는 전달하지 않는다.
- 공유는 두 패널의 전체 RepaintBoundary를 세로로 합성한다. 스크롤 viewport와 hinge gap을 캡처 범위로 삼지 않는다. 메모리/texture 크기에 맞춰 전체 이미지를 축소하며 내용을 잘라내지 않는다.
- 홈 배너는 SafeArea 안의 실제 표시 너비와 방향을 측정한다. 400ms debounce, 요청 세대 번호, mounted 및 구독 권한 검사로 재로딩 경쟁을 처리한다.
- 로그인·온보딩·설정·프리셋·구독 흐름은 안전한 영역에서 스크롤하며, 긴 버튼/가격은 현재 너비에 맞게 줄바꿈한다.

## 6. Windows에서 수행한 검증

- 변경 전: flutter test 107개 통과. flutter analyze의 기존 info 3개는 파일명 2개와 폐기된 배너 API 1개.
- 변경 후: flutter test 124개 통과. 새 회귀 테스트 17개 포함.
- flutter analyze: error / warning 없음. 기존 Camera_Screen.dart, Home_Screen.dart의 file_names info 2개만 남음. 이 info 때문에 명령 exit code는 1이다.
- 변경한 Dart 파일 포맷 수행.
- Android debug APK 빌드 성공: `build/app/outputs/flutter-apk/app-debug.apk`.
- 로컬 plist/XML 및 plugin registration/scene 구성 정적 점검. 기존 Info.plist의 민감 설정 값 보존 확인.
- 실제 광고·결제 요청 대신 factory/CTA 대역, 시스템 카메라 대신 ImagePicker 대역, 분석 대신 대기 Future를 사용했다. 결제 entitlement/복원 및 광고 빈도 정책의 기존 테스트도 통과했다.

테스트에서는 같은 위젯을 연속으로 리사이즈한다. 390×844, 1100×800, 낮은 960×320 및 1000×200, 320×700 분할 창, 세로 hinge, 가로 half-open fold, 좌우 SafeArea, 키보드, 2배 글자 및 RTL을 다룬다. 실제 LoadingScreen 요청 1회, picker 1회, 입력·메뉴 선택·양쪽 스크롤 유지, 늦은 광고 응답 폐기, 멀티 이미지 선택, 화면 밖 결과의 공유 bitmap 포함을 검증한다.

## 7. Mac에서 필수 검증

Windows에는 Xcode / iOS simulator / 연결된 Android 실기기가 없어 아래 항목을 실행하지 않았다. iPhone Duo, Fold8/Fold/Flip 및 다른 폴더블의 하드웨어 동작을 검증 완료로 표시하지 않는다.

**Xcode 27에는 Flutter 3.44.8 이상이 필요하다.** [Flutter 공식 CHANGELOG](https://github.com/flutter/flutter/blob/master/CHANGELOG.md)는 3.44.8에서 Xcode 27의 lipo verification 빌드 오류 수정을 기록한다. Dart 구현 API는 3.44.7로 검증했고 공유 Windows SDK는 변경하지 않았다. 프로젝트의 Flutter API 하한은 3.44.7이며, Mac에서 Xcode 27을 사용하는 경우 최소 patch update 3.44.8을 적용한 별도 SDK로 검증한다. 이 문서만으로 실제 iOS 27 빌드 성공을 보증하지 않는다.

기존 설정 파일과 AppDelegate 변경을 복원한 Mac 작업 폴더에서 실행한다.

```sh
flutter --version
xcodebuild -version
xcodebuild -showsdks
flutter doctor -v
flutter pub get
plutil -lint ios/Runner/Info.plist ios/Flutter/AppFrameworkInfo.plist
flutter build ios --config-only --no-codesign
cd ios
pod install
cd ..
flutter analyze
flutter test
flutter build ios --simulator --debug --dart-define=MSCANNER_VISION_V3=true
flutter build ios --release --no-codesign --dart-define=MSCANNER_VISION_V3=true
flutter devices
flutter run -d <ios-device-id> --dart-define=MSCANNER_VISION_V3=true
```

CocoaPods는 원래 루트 Runner workspace에 Pods 프로젝트를 연결해야 한다. Xcode에서 Main.storyboard의 initial FlutterViewController, AppDelegate 타깃 포함, effective deployment target 15.0 및 scene delegate 연결을 확인한다. 다른 Xcode/Flutter patch를 사용했다면 그 버전과 build 결과를 기록한다.

SDK patch 변경 후 Android 회귀 확인도 실행한다.

```sh
flutter test
flutter build apk --debug --dart-define=MSCANNER_VISION_V3=true
```

다음 표는 **미실행 수동 검증**이다. 지원되는 실기기/시뮬레이터에서 결과를 채운다. iOS에서 접힘 정보가 제공되는지 먼저 기록하고, 정보가 없어도 창 크기만으로 레이아웃이 전환되는지 확인한다.

| 환경 | 확인 절차 |
| --- | --- |
| 일반 iPhone / Android | 세로·가로, 큰 글자, RTL, 키보드, OS 회전 잠금 |
| iPhone Duo | 접기·펼치기·회전·지원되는 창 크기 변경, scene foreground/background |
| Galaxy Fold8 / 기존 Fold | 외부↔내부 화면, 분할 창 크기 변경, 분석 중 전환 |
| Galaxy Flip | 펼침·가로·반접힘, 가로 경계, 닫았다가 앱 복귀 |
| 다른 Android 폴더블 | 세로/가로 경계 제공 여부, 멀티윈도우, 연속 resize |
| 촬영 / 멀티 스캔 | 시스템 촬영 승인·취소, 갤러리 선택, 복귀 후 picker 재호출 여부 |
| 결과 | 원본 확대·페이지 넘김·확대 상태, 사진 선택, 번역·설명·환율, 리뷰 및 양쪽 스크롤 |
| 공유 / 저장 | 두 패널 및 마지막 결과/리뷰까지 포함, 공유 popover, Firebase 저장 |
| 로그인 / 지도 | Google callback의 warm/cold 복귀, Apple 로그인, 지도 platform view 표시·복귀 |
| 광고 / 구매 | 테스트 광고의 resize·구독 시 제거, 기존 전면광고 시점, StoreKit/Play 테스트 구매·복원 |

강제 프로세스 종료 후 복구와 실제 카메라/스토어/광고 SDK의 플랫폼 생명주기는 위젯 테스트의 범위 밖이며 수동 검증 결과에 함께 기록한다.
