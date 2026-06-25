import Foundation

/// 앱 전역 설정 및 외부 서비스 연동에 필요한 상수 모음.
///
/// Adobe Lightroom 연동을 사용하려면 Adobe Developer Console
/// (https://developer.adobe.com/console) 에서 프로젝트를 생성하고
/// "Lightroom Services API" 를 추가한 뒤 발급받은 자격 증명을 입력하세요.
///
/// - `clientID` (API Key)
/// - OAuth Redirect URI 에는 아래 `redirectURI` 값을 등록해야 합니다.
enum AppConfig {

    enum Lightroom {
        /// Adobe Developer Console 에서 발급받은 Client ID (API Key).
        /// OAuth Native App(PKCE) 자격 증명이므로 client secret 이 없으며,
        /// 이 ID 는 공개되어도 무방하다 (앱에 포함되는 공개 식별자).
        static let clientID = "107a55d89a31478c84f2f0f313a4ab22"

        /// OAuth 인증 후 앱으로 돌아오기 위한 리디렉션 URI.
        /// Adobe OAuth Native App 은 redirect URI 를 자동 생성하며,
        /// 형식은 `adobe+<hash>://adobeid/<client_id>` 이다.
        /// Info.plist 의 CFBundleURLSchemes 및 Adobe Console 설정과 반드시 일치해야 한다.
        static let redirectURI = "adobe+fea1fa140a9c3f2ceeff3aeff353ce1efda56c0d://adobeid/107a55d89a31478c84f2f0f313a4ab22"

        /// 커스텀 스킴 (ASWebAuthenticationSession 콜백 매칭용).
        /// redirectURI 의 scheme 부분과 동일해야 한다.
        static let callbackScheme = "adobe+fea1fa140a9c3f2ceeff3aeff353ce1efda56c0d"

        /// Adobe IMS / Lightroom API 엔드포인트.
        static let authorizeURL = "https://ims-na1.adobelogin.com/ims/authorize/v2"
        static let tokenURL = "https://ims-na1.adobelogin.com/ims/token/v3"
        static let apiBaseURL = "https://lr.adobe.io/v2"

        /// Lightroom 파트너 API 사용에 필요한 OAuth 스코프.
        /// lr_partner_rendition_apis 는 사진 렌디션(이미지) 다운로드에 필요하다.
        static let scopes = "openid,AdobeID,lr_partner_apis,lr_partner_rendition_apis,offline_access"

        /// 자격 증명이 설정되었는지 여부.
        static var isConfigured: Bool {
            !clientID.isEmpty && clientID != "YOUR_ADOBE_CLIENT_ID"
        }

        /// Adobe Lightroom 파트너 API 승인 대기 상태.
        /// `lr_partner_apis` 는 Adobe 의 파트너 승인이 있어야 인증이 가능하다.
        /// 승인이 완료되면 false 로 바꾸면 정상 로그인/앨범 조회가 활성화된다.
        static let partnerApprovalPending = true
    }

    /// 슬라이드쇼 기본 전환 간격(초).
    static let defaultSlideInterval: TimeInterval = 8
}
