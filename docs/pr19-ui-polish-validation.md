# PR19 UI Polish 검증 기록

브랜치: `agent/pr19-my-food-journey`

## 수정 파일

- `lib/features/food_journey/widgets/food_journey_style.dart` (신규): 미식 여행 전용 색상·라운드 토큰
- `lib/features/food_journey/widgets/food_journey_icons.dart` (신규): 공통 벡터 아이콘
- `lib/features/food_journey/widgets/food_journey_home_card.dart`: 홈 카드, 구분선, 기준 pill, 반응형 배치 및 상태 스타일
- `lib/features/food_journey/widgets/food_journey_sections.dart`: 여권·국가 카드, 날짜 아이콘, DNA 상위 유형과 차트
- `lib/features/food_journey/screens/food_journey_screen.dart`: 페이지·AppBar 색상과 로딩·오류·빈 상태 카드
- `lib/widgets/result/scan_image_preview.dart` (신규): 화면 크기에 따른 대표 사진 제한
- `lib/screens/result_screen.dart`: 새 미리보기와 compact 썸네일 옵션 연결
- `lib/widgets/image_grid_viewer.dart`: 선택 테두리가 있는 가로 썸네일 옵션
- `test/food_journey_home_card_test.dart`: 카드 색상·상태·언어·테마 검증 확장
- `test/food_journey_screen_test.dart`: 페이지·내부 카드 색상 및 언어·테마 검증 확장
- `test/compact_scan_preview_test.dart` (신규): 사진 크기, 선택, RTL, 가로 스크롤 및 캡처 검증
- 이 문서

## 디자인

밝은 모드의 페이지·AppBar는 `#EFEFF4`, 카드 `#FFF9F6`, 보조 바탕 `#FFF3ED`, 국가 내부 카드 흰색, 테두리 `#FFD9C7`, 아이콘·진행률 `#FF7A45`, 강조 텍스트 `#E35D2F`, 일반 텍스트 `#1E1E1E`·`#6B6B6B`를 사용한다. 공통 카드 radius는 20dp, 국가 카드는 14dp, 차트 높이는 7dp다.

다크모드에서는 기존 앱의 페이지 배경과 별도의 어두운 카드·따뜻한 오렌지 포인트를 사용한다. 전역 ThemeData와 홈의 기존 배경·다른 카드는 수정하지 않았다.

지구본, DNA, 밥그릇, 생선, 국물, 채소, 디저트, 음료, 달력, 통계는 설치된 Phosphor Regular 아이콘을 재사용한다. 여권·면 요리·스테이크는 같은 선 스타일의 CustomPainter로 구현했다. FoodJourneyIcon에서 크기·색상·선택적 접근성 레이블을 제공하며, 장식 아이콘은 중복 낭독을 피한다. 국가 국기는 기존 표시를 유지했다. 패키지·외부 에셋은 추가하지 않았다.

## 결과 사진 크기

- 휴대폰: 현재 창 높이의 30%, 최소 180dp·최대 260dp. 예: 320×568 → 180dp, 390×844 → 253.2dp, 430×932 → 260dp.
- 큰 패널: 창의 짧은 변이 600dp 이상이고 해당 패널 너비가 360dp 이상이면 창 높이의 40%, 최소 240dp·최대 360dp. 예: 1100×800 → 320dp.
- 미리보기 radius 16dp, BoxFit.contain, 원본 파일과 전체 화면 확대 진입 콜백 유지.
- 멀티 스캔: 썸네일 72×72dp, 간격 8dp, 가로 한 줄, 선택 항목에 2dp 오렌지 테두리. 사진 한 장은 목록 숨김.
- FileThumbnail의 ResizeImage와 픽셀 밀도에 따른 디코딩 크기를 재사용한다. 기본 ImageGridViewer의 줄바꿈 그리드는 유지한다.

## 검증

- `dart format lib test`: 실행 완료. 작업 범위 밖 세 파일의 기존 포맷은 보존했다.
- `flutter test --no-pub --concurrency=4`: **152개 전체 통과**.
- `flutter analyze`: 기존 진단 4건, 신규 진단 없음. 아래 파일은 이번 작업에서 수정하지 않았다.
  - `lib/screens/Camera_Screen.dart`, `lib/screens/Home_Screen.dart`: 파일명 info 각 1건.
  - `lib/services/account_upgrade_service.dart:130`, `:190`: `unawaited_return_in_try_block` warning 각 1건.
- `flutter build apk --debug`: 성공. 산출물 `build/app/outputs/flutter-apk/app-debug.apk`.
  - 변경하지 않은 Android 설정·의존성에 대한 KGP 버전 및 플러그인의 Built-in Kotlin 전환 경고가 남아 있다. 이번 작업에서 네이티브 설정은 수정하지 않았다.
- `git diff --check`: 통과.
- 모든 지원 언어의 홈·상세를 280dp 너비·글자 2배에서 밝은 모드와 다크모드로 검사했다. 아랍어 RTL과 긴 비율 문구의 줄바꿈을 검증했다.
- 휴대폰 가로·세로, 넓은 화면, 폴더블 힌지·패널 전환, 스크롤·선택 유지, 대표 사진 크기 및 한 줄 썸네일을 검사했다.
- 실제 이미지 파일을 이용해 썸네일 선택 후 대표 이미지가 바뀌고, 캡처 비트맵에 화면 밖 결과 하단까지 포함되는 것을 검사했다.
- 한글 폰트와 실제 아이콘으로 홈·상세·다크·넓은 화면을 렌더링해 시각 검토했다. Windows 테스트 렌더러에는 국가 국기 이모지 폰트가 없어 국기의 기기별 표시는 별도 확인 대상이다.

## 보존 범위와 미검증 사항

AdaptiveScanPanels, RepaintBoundary, ScrollController, ScanCaptureController 및 내보내기 합성 코드는 변경하지 않았다. 기존 패널·캡처 회귀 테스트가 통과했다.

단일·멀티 스캔 분석, 스트리밍 Vision AI, 빠른 선택·추천, 전체 메뉴, 자동 환율, RAG, 주문 문구, 프리미엄, 저장·공유·전체 화면 확대, 뒤로가기·광고 정책의 로직은 변경하지 않았다. 국가 집계·정렬, DNA 분류·비율 계산, 조회·추가 로딩 정책, Firebase·Firestore 구조, 결제, 네이티브 설정도 그대로다.

연결된 Android 13 기기(SM-G981N)에 `adb install -r`로 업데이트를 시도했으나, 설치된 앱과 디버그 APK의 서명이 달라 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`로 거부됐다. 기존 앱을 삭제하거나 데이터를 지우지 않았다. 따라서 변경된 APK의 Android 실기기 UI 실행은 미검증이다.

iPhone/iOS 실기기·시뮬레이터 실행, 실기기 폴더블, 운영 AI 응답, 전체 화면 사진 확대·닫기, 저장·공유의 OS 화면까지 이어지는 수동 검증도 미실행이다. 자동 검증과 기기 실행 검증을 구분한다.
