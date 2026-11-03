import Foundation

/// Geometry and timing shared by the native frame and its regression checks.
/// Coordinates match the Android PremiumAvatarFrame's 100-point drawing space.
public enum PremiumAvatarAppearance {
    public static let photoDiameterRatio = 0.83
    public static let photoCenterYRatio = 0.53
    public static let ringRadius = 43.0
    public static let ringWidth = 4.5
    public static let sweepDuration = 4.8
    public static let sparkleDuration = 3.4
    public static let restingPhase = 0.32

    public static func phase(elapsed: TimeInterval, duration: TimeInterval) -> Double {
        guard elapsed.isFinite, duration.isFinite, duration > 0 else { return restingPhase }
        let remainder = elapsed.truncatingRemainder(dividingBy: duration) / duration
        return remainder < 0 ? remainder + 1 : remainder
    }

    public static func animates(isPremium: Bool, reduceMotion: Bool, sceneActive: Bool, visible: Bool) -> Bool {
        isPremium && !reduceMotion && sceneActive && visible
    }
}

public enum PremiumAvatarL10n {
    public static var verifiedMember: String {
        NSLocalizedString("verifiedMember", tableName: "PremiumAvatar", bundle: .module, comment: "Premium username badge")
    }
    public static var frame: String {
        NSLocalizedString("frame", tableName: "PremiumAvatar", bundle: .module, comment: "Premium avatar frame")
    }
}
