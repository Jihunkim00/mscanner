# 디자인 A UI 리팩터링 작업 보고서

작업일: 2026-11-14. 기존 기능·데이터 모델·라우팅을 유지하는 Flutter UI 변경이다.

## 수정 전 조사 결과

- `main.dart`의 `AdaptiveTheme`는 기본 파란색 `ThemeData`만 지정했다. 별도의 공통 `ColorScheme`과 `TextTheme`는 없었고, `styles/Text_Styles.dart`에는 SFPro 개별 텍스트 스타일 3개가 있었다.
- Preset 화면의 `AppBar.leading`에는 Flutter 기본 `CupertinoNavigationBarBackButton`이 사용되고 있었다. 별도 공통 AppBar 위젯은 확인되지 않았다.
- 홈은 음식 이미지 캐러셀, 최신 좋아요/저장 입력, 미식 여행 요약, 사용 방법, 광고, 댓글로 구성되어 있다. 하단 내비게이션은 `BottomNavigationBar` 5개 탭이다.
- 기록은 `History_Screen.dart`의 저장/지도 세그먼트 아래에 `FavoriteListScreen` 또는 `MapScreen`을 표시한다.
- 검색창과 필터는 이미 `MScannerSearchField`, `MScannerPillChip`, `MScannerSearchUi`를 공유하고 있었다. 이 구현을 확장했다.
- 미식 여행의 `FoodJourneyStyle`은 별도 오렌지 배경·테두리를 사용했다. 각 화면에도 회색/오렌지/검정 등의 직접 지정이 있었다.
- 언어 목록은 `helpers/l10n.dart`, 문자열과 방향은 기존 Flutter localization delegate가 관리한다. 기존 지원 언어와 번역 키를 유지했다.
- `AdaptivePage`, `AdaptiveContent`, `AdaptiveModalSurface`가 창 크기, SafeArea, 팝업 영역을 지원하고 있어 재사용했다.

## 변경 파일

| 파일 | 변경 사항 |
| --- | --- |
| `lib/styles/app_theme.dart` (신규) | 공통 라이트/다크 색상, Material/Cupertino 테마, 카드·입력·버튼·칩·AppBar·하단 내비게이션 기본값 |
| `lib/styles/Text_Styles.dart` | 기존 SFPro 스타일을 유지하고 공통 `TextTheme` 추가 |
| `lib/main.dart` | 기존 AdaptiveTheme의 라이트/다크 테마를 공통 테마로 연결 |
| `lib/features/food_journey/widgets/food_journey_style.dart` | 별도 팔레트를 공통 토큰으로 연결 |
| `lib/features/food_journey/screens/food_journey_screen.dart` | Preset과 동일한 기본 뒤로가기 컴포넌트 사용 |
| `lib/features/food_journey/widgets/food_journey_sections.dart` | 여권의 국가·기록 수·날짜 계층, DNA 막대·빈 카테고리 표시 정리 |
| `lib/features/food_journey/widgets/food_journey_home_card.dart` | 홈 요약 카드의 공통 색상·모서리·제목 스타일 적용 |
| `lib/screens/History_Screen.dart` | 저장/지도 활성 색상 통일, 고정 높이 내비게이션 영역 대신 글자 크기를 따르는 세그먼트 배치 |
| `lib/screens/favorite_list_screen.dart` | 저장 카드, 이미지 비율, 별점·날짜·선택 정렬, 월별 헤더 표시 개선 |
| `lib/screens/map_screen.dart` | 마커 색상, 하단 카드, 검색/필터 배치, 날짜/위치 팝업 스타일 개선 |
| `lib/screens/home_screen.dart` | 배경·검색·최신 저장 카드·캐러셀 글자 확대 대응·하단 내비게이션 개선 |
| `lib/widgets/how_to_use_mscanner_card.dart` | 흰색 카드, 중립 아이콘 배경, 좁은 화면/글자 확대 시 단계별 세로 배치 |
| `lib/widgets/mscanner_search_ui.dart` | 기존 공통 검색창·필터에 브랜드 색상, 중립 배경, 공통 글자·모서리·방향 여백 적용 |
| `test/food_journey_screen_test.dart` | 새 팔레트, 뒤로가기 동작, 로케일·RTL·확대 글자 회귀 검증 |
| `test/food_journey_home_card_test.dart` | 새 공통 테마 및 카드 기대값 반영 |
| `test/clean_airy_ui_test.dart` (신규) | 공통 UI의 대비, 검색/필터 콜백, 카드 선택/이미지/상세 동작, 세그먼트, 5개 탭, 작은 화면·다국어 검증 |
| `test/clean_airy_golden_test.dart` (신규) | 실제 앱 폰트를 사용한 홈 카드·기록 카드·미식 여행 시각 회귀 검증 |
| `test/support/app_test_fonts.dart` (신규) | 테스트용 앱 폰트 로더 |
| `test/goldens/*.png` (신규 8장) | 홈 카드·기록 카드·미식 여권·미식 DNA의 라이트/다크 기준 이미지 |
| `docs/ui-design-a.md` (신규) | 분석, 변경 범위, 검증 및 남은 확인 사항 |

작업 시작 전부터 수정되어 있던 `pubspec.yaml`의 버전과 `.flutter-plugins-dependencies`는 되돌리지 않았다. 의존성·버전 변경을 이번 UI 작업에 추가하지 않았다.

## 공통 디자인

라이트 색상: Primary `#B84928`, Background `#FAF8F5`, Surface `#FFFFFF`, Text `#222622`, Secondary text `#69716C`, Subtle surface `#F4EEE9`, Border `#EAE5DF`.

다크 모드는 별도 중립 배경·표면·테두리와 밝은 브랜드 강조색을 사용한다. 오류 등 Material 의미 색상은 `ColorScheme`의 의미를 유지한다. 현재 테마의 밝기를 사용하므로 시스템 모드에서도 화면별 색상이 일치한다.

SFPro와 기존 폰트 자산/플랫폼 fallback을 유지했다. 공통 크기는 페이지 제목 24, AppBar 20, 카드 제목 17, 본문 14/16, 보조 13, 메타 12, 버튼·필터 13/14다. 기본 카드 모서리는 16, 컨트롤은 12이며 카드 그림자는 제거했다.

## 뒤로가기 재사용

원본은 `lib/screens/preset_selection_screen.dart`의 `AppBar.leading`이다. 같은 Flutter 기본 `CupertinoNavigationBarBackButton`을 미식 여행의 `AppBar.leading`에 사용했다. 별도 버튼 클래스, 원형 배경, 테두리, 그림자를 추가하지 않았다. 기본 AppBar의 leading 영역과 여백을 유지한다.

Cupertino 화살표는 내부적으로 폰트 글리프이므로, 아이콘 영역만 `MediaQuery.withNoTextScaling`으로 기존 크기를 유지한다. 본문 텍스트 확대에는 영향을 주지 않는다. 아랍어 200%에서 발견한 화살표 overflow를 이 방식으로 수정했고, 양 플랫폼에서 RTL과 실제 route pop을 테스트했다.

## 화면별 결과와 기능 유지

- 미식 여권: 흰색 표면과 얇은 중립 테두리, 작은 국기, 국가명/스캔 수와 날짜 사이 구분선. 기존 국가·날짜·기록 수를 모두 유지한다.
- 미식 DNA: 실제 데이터가 있는 항목의 막대를 5px로 통일하고 상위 항목을 강조한다. 0% 카테고리는 간결한 텍스트로 남겨 작은 데이터에서 빈 막대가 차지하던 공간을 줄였다. 기존 순위·분류·비율 계산을 그대로 사용한다.
- 저장: 이미지 64×64, 제목/가게명/메타데이터 계층, 그림자 없는 카드. 메뉴명 fallback이 가게명과 같은 경우 표시만 한 번으로 줄인다. 큰 글자에서는 이미지·체크박스와 본문이 세로로 배치된다. 그룹 키·정렬은 유지하고 월 이름의 표시만 현지화한다.
- 지도: 기존 Google Maps 지도 스타일과 좌표·마커 ID·콜백·필터링을 유지한다. 기본 마커 색상만 오렌지로 변경했다. 지도와 카드 영역을 나누어 지도 조작 버튼이 카드에 가려지지 않게 했다. 카드의 선택 테두리와 정보창 동작을 유지하며, 긴 텍스트는 카드 안에서 스크롤할 수 있다. 날짜 팝업의 고정 0.92배 텍스트 설정과 고정 전체 높이를 제거했다.
- 홈: 캐러셀·최신 저장·여행 요약·사용 방법·광고·댓글과 모든 액션을 유지한다. 검색창은 글자 크기에 따라 높이가 늘어나고, 캐러셀 높이도 확대 글자에 대응한다.
- 하단 내비게이션: 기존 5개 항목, 번역 키, `_onItemTapped`, 선택 상태 및 SafeArea 동작을 유지한다. 세 번째 탭의 기존 `multiScan` 키/동작도 그대로다. 아이콘 24, 라벨 12, 활성 브랜드 색상·비활성 중립 회색을 적용했다. 테스트를 위해 기존 표시 부분을 같은 파일의 위젯으로 추출했다.

Vision AI, 멀티스캔, 번역, 환율, 인증, 결제, Firestore/Storage 조회·모델·경로, Geohash/RAG, 기존 데이터 및 라우팅 계약은 변경하지 않았다. 데이터 마이그레이션은 없다.

## 검증 결과

- Flutter 3.47.9 / Dart 3.13.7 / Windows에서 실행.
- `flutter analyze`: **No issues found**.
- `flutter test`: **168개 전체 통과**. 기존 비즈니스 로직 테스트와 새 UI/골든 테스트를 포함한다.
- `git diff --check`: 통과.
- UI 테스트: 너비 280px, 글자 크기 200%, 모든 기존 지원 로케일, 라이트/다크 및 Android/iOS `TargetPlatform`, 아랍어 RTL에서 RenderFlex 오류 없음.
- 공통 UI 테스트에는 앱에 포함된 폰트를 실제로 로드했다. 미식 여행의 기존 넓은 화면/페이지 추가 로딩/계정 분리 테스트도 통과했다.
- 저장 카드 상세/이미지/체크박스 콜백, 검색 입력/필터, 저장·지도 세그먼트, 5개 탭, 시스템 하단 inset, 뒤로가기 route pop을 위젯 테스트로 확인했다.
- 골든 8장 생성 후 **갱신 옵션 없이** 전체 테스트로 이미지 일치를 다시 검증했다. 생성 명령은 `flutter test --update-goldens test/clean_airy_golden_test.dart`다.

## 실기기에서 남은 확인

이번에는 기기에 앱을 설치·실행하지 않았다. Android 기기 연결은 확인했으며 iOS 기기는 연결되어 있지 않았다. 플랫폼 테마를 사용하는 위젯 테스트는 네이티브 실행 검증과 구별해야 한다.

Android/iOS에서 네트워크 음식 사진, Google Maps 조작·선택·필터 및 날짜 선택, 실제 저장/삭제/상세 이동, 캐러셀, 네이티브 폰트 fallback·국기 이모지·VoiceOver/TalkBack을 확인해야 한다. 작은 기기의 가로 방향과 OS 최대 글자 크기도 추가 확인 대상이다. 골든은 Firestore나 네이티브 지도를 호출하지 않는 고정 fixture이며 테스트 엔진의 국기 글리프는 기기 이모지 표시와 다를 수 있다. 전체 홈과 네이티브 지도의 실기기 스크린샷을 대신하지 않는다.
