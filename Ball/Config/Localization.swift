import Foundation

// MARK: - Translations

/// The game's data (ball, ability and arena names and descriptions) stays in English, so online
/// fingerprints match across languages; it's translated only for display, with the English text as the
/// key in `Localizable.xcstrings`. Screen text written in views is localized by SwiftUI as usual.
nonisolated extension String {
    /// This text in the player's language, or unchanged when there's no translation.
    var localized: String { Bundle.main.localizedString(forKey: self, value: self, table: nil) }
}
