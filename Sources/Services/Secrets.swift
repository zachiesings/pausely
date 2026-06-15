import Foundation

/// App-level secrets. The RevenueCat **public** SDK key is safe to ship in the
/// client binary (it is not a server secret), but must be set before release.
///
/// Get it from RevenueCat → Project → API keys → "Public app-specific API key"
/// for the Apple App Store app (starts with `appl_`).
enum Secrets {
    static let revenueCatKey = "appl_REPLACE_WITH_PAUSELY_REVENUECAT_KEY"
}
