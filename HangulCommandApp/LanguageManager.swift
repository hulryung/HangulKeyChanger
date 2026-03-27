import Foundation
import Combine

class LanguageManager {
    static let shared = LanguageManager()

    @Published var language: String

    private var bundle: Bundle

    private init() {
        let saved = UserDefaults.standard.string(forKey: "AppLanguage")
        let lang = saved ?? LanguageManager.systemLanguage()
        self.language = lang
        self.bundle = LanguageManager.loadBundle(for: lang)
    }

    func setLanguage(_ lang: String) {
        language = lang
        bundle = LanguageManager.loadBundle(for: lang)
        UserDefaults.standard.set(lang, forKey: "AppLanguage")
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private static func systemLanguage() -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ko") ? "ko" : "en"
    }

    private static func loadBundle(for lang: String) -> Bundle {
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let b = Bundle(path: path) {
            return b
        }
        return Bundle.main
    }
}
