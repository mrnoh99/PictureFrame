# PictureFrame

iOS 사진 앱의 특정 앨범과 Adobe Lightroom 사용자 앨범에서 사진을 가져와 다양한 방식으로 액자처럼 보여주는 SwiftUI 앱.

## 주요 기능

| 기능 | 설명 |
|------|------|
| **iOS 사진 앨범 연동** | PhotoKit으로 사용자 앨범, 스마트 앨범(즐겨찾기·최근 등) 접근 |
| **Lightroom 앨범 연동** | Adobe IMS OAuth 2.0 PKCE 인증 → Lightroom Services API v2 |
| **슬라이드쇼** | Ken Burns(팬/줌) 효과 + 크로스페이드 전환, 간격 설정 가능 |
| **콜라주** | 2~9장 사진을 한 화면에 모자이크 레이아웃으로 배치 |
| **그리드 갤러리** | 전체 사진을 격자로 스크롤, 탭하면 전체화면 |
| **화면 꺼짐 방지** | 액자 모드에서 `isIdleTimerDisabled = true` |
| **iPad 가로 기본** | 거치형 액자에 맞춰 iPad·iPhone 모두 가로(Landscape) 전용으로 동작 |

## 요구 사항

- iOS 17.0+
- Xcode 16.0+
- iPad 가로(Landscape) 방향 기본 (세로 모드는 비활성화)
- Adobe Developer Console API 자격 증명 (Lightroom 연동 시)

## Lightroom 연동 설정

1. [Adobe Developer Console](https://developer.adobe.com/console) 에서 새 프로젝트 생성
2. **Lightroom Services API** 추가
3. 자격 증명(Credential) 으로 **OAuth → Native App** 선택
   - Native App 은 client secret 이 없고 PKCE 를 사용하므로 모바일 앱에 적합
   - **Redirect URI 는 Adobe 가 자동 생성**한다 (`adobe+<hash>://adobeid/<client_id>` 형식)
4. 생성된 값들을 `PictureFrame/Config/AppConfig.swift` 에 입력:
   - `clientID` ← Client ID
   - `redirectURI` ← Adobe 가 생성한 Redirect URI 전체
   - `callbackScheme` ← Redirect URI 의 scheme 부분 (`adobe+<hash>`)
5. `Info.plist` 의 `CFBundleURLSchemes` 를 위 `callbackScheme` 과 동일하게 설정
6. Scopes 에 `lr_partner_apis` 와 **`lr_partner_rendition_apis`**(이미지 다운로드용) 포함 확인

```swift
// AppConfig.swift — Adobe Console 값으로 교체
static let clientID      = "107a55d89a31478c84f2f0f313a4ab22"
static let redirectURI   = "adobe+<hash>://adobeid/<client_id>"
static let callbackScheme = "adobe+<hash>"
```

> 💡 Client ID 와 Redirect URI 는 PKCE 기반 Native App 의 **공개 식별자**이며 client secret 이 아니므로 앱·저장소에 포함되어도 보안상 문제없다.

## 프로젝트 구조

```
PictureFrame/
├── Config/
│   └── AppConfig.swift          # Lightroom API 엔드포인트 및 상수
├── Models/
│   ├── FramePhoto.swift         # 사진 도메인 모델
│   ├── Album.swift              # 앨범 + AlbumSelection 모델
│   └── DisplayMode.swift        # 슬라이드쇼/콜라주/그리드 열거형
├── Services/
│   ├── PhotoProvider.swift      # 공통 프로토콜
│   ├── PhotoLibraryService.swift# PhotoKit 구현체
│   └── Lightroom/
│       ├── KeychainStore.swift  # 토큰 보안 저장
│       ├── LightroomAuthService.swift  # OAuth PKCE 플로우
│       ├── LightroomAPIClient.swift    # REST API 클라이언트
│       ├── LightroomModels.swift       # API 응답 모델
│       └── LightroomService.swift      # PhotoProvider 구현체
├── ViewModels/
│   ├── SettingsStore.swift      # 설정 영속화 (UserDefaults)
│   └── FrameViewModel.swift     # 액자 화면 비즈니스 로직
└── Views/
    ├── RootView.swift
    ├── WelcomeView.swift
    ├── FrameContainerView.swift
    ├── AsyncPhotoView.swift     # 비동기 이미지 로딩 컴포넌트
    ├── SlideshowView.swift      # Ken Burns 슬라이드쇼
    ├── CollageView.swift        # 모자이크 콜라주
    ├── GridGalleryView.swift    # 격자 갤러리 + 전체화면
    └── Settings/
        ├── SettingsView.swift
        ├── AlbumPickerView.swift
        └── LightroomSetupView.swift
```

## 보안 고려 사항

- 액세스 토큰/리프레시 토큰은 모두 **Keychain** 에 저장 (`kSecAttrAccessibleAfterFirstUnlock`)
- OAuth 플로우는 **PKCE** (S256) 적용으로 인증 코드 탈취 방어
- Client ID 는 소스에 직접 두지 말고 xcconfig/환경변수로 주입 권장
