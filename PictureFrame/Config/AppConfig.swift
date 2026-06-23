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
        /// 실제 값으로 교체하세요. 비워두면 Lightroom 연동 화면에서 안내가 표시됩니다.
        static let clientID = "YOUR_ADOBE_CLIENT_ID"

        /// OAuth 인증 후 앱으로 돌아오기 위한 커스텀 URL 스킴 기반 리디렉션 URI.
        /// Info.plist 의 CFBundleURLSchemes 및 Adobe Console 설정과 반드시 일치해야 합니다.
        static let redirectURI = "pictureframe://oauth/lightroom"

        /// 커스텀 스킴 (ASWebAuthenticationSession 콜백 매칭용).
        static let callbackScheme = "pictureframe"

        /// Adobe IMS / Lightroom API 엔드포인트.
        static let authorizeURL = "https://ims-na1.adobelogin.com/ims/authorize/v2"
        static let tokenURL = "https://ims-na1.adobelogin.com/ims/token/v3"
        static let apiBaseURL = "https://lr.adobe.io/v2"

        /// Lightroom 파트너 API 사용에 필요한 OAuth 스코프.
        static let scopes = "openid,AdobeID,lr_partner_apis,offline_access"

        /// 자격 증명이 설정되었는지 여부.
        static var isConfigured: Bool {
            !clientID.isEmpty && clientID != "YOUR_ADOBE_CLIENT_ID"
        }
    }

    /// 슬라이드쇼 기본 전환 간격(초).
    static let defaultSlideInterval: TimeInterval = 8
}
