import Foundation

/// Lightroom Services API 응답 모델들.
/// 참고: 모든 응답 본문은 JSON 하이재킹 방지를 위해 `while (1) {}` 접두사가 붙어 있으므로
/// 디코딩 전에 제거해야 한다 (LightroomAPIClient 에서 처리).

struct LightroomCatalog: Decodable {
    let id: String
}

struct LightroomAlbumList: Decodable {
    let resources: [LightroomAlbum]
}

struct LightroomAlbum: Decodable {
    let id: String
    let subtype: String?
    let payload: Payload?

    struct Payload: Decodable {
        let name: String?
    }

    var name: String { payload?.name ?? "제목 없음" }
}

struct LightroomAssetList: Decodable {
    let resources: [LightroomAlbumAssetRef]
}

/// 앨범 내 자산은 `asset` 하위에 실제 자산이 들어있다.
struct LightroomAlbumAssetRef: Decodable {
    let asset: LightroomAsset
}

struct LightroomAsset: Decodable {
    let id: String
    let payload: Payload?

    struct Payload: Decodable {
        let captureDate: String?
        let develop: Develop?
        let importSource: ImportSource?

        struct Develop: Decodable {
            let croppedWidth: Double?
            let croppedHeight: Double?
        }
        struct ImportSource: Decodable {
            let originalWidth: Double?
            let originalHeight: Double?
        }
    }

    var captureDate: Date? {
        guard let raw = payload?.captureDate else { return nil }
        return ISO8601DateFormatter().date(from: raw)
            ?? LightroomAsset.fallbackFormatter.date(from: raw)
    }

    var aspectRatio: CGFloat? {
        if let w = payload?.develop?.croppedWidth, let h = payload?.develop?.croppedHeight, h > 0 {
            return CGFloat(w / h)
        }
        if let w = payload?.importSource?.originalWidth, let h = payload?.importSource?.originalHeight, h > 0 {
            return CGFloat(w / h)
        }
        return nil
    }

    private static let fallbackFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
