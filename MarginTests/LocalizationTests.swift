import Foundation
import Testing

struct LocalizationTests {
    @Test(arguments: ["en", "zh-Hans", "zh-Hant", "ja", "ko", "es"])
    func includesCompleteStringTables(for language: String) throws {
        #expect(Bundle.main.localizations.contains(language))

        for table in ["Localizable", "InfoPlist"] {
            let reference = try strings(table: table, language: "en")
            let localized = try strings(table: table, language: language)
            let missing = Set(reference.keys).subtracting(localized.keys)
            let extra = Set(localized.keys).subtracting(reference.keys)
            #expect(!reference.isEmpty)
            #expect(missing.isEmpty, "\(language)/\(table) is missing \(missing.sorted())")
            #expect(extra.isEmpty, "\(language)/\(table) has extra keys \(extra.sorted())")

            for (key, original) in reference {
                guard let translation = localized[key] else { continue }
                #expect(!translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(language): \(key)")
                #expect(placeholders(in: translation) == placeholders(in: original), "\(language): \(key)")
            }
        }
    }

    private func strings(table: String, language: String) throws -> [String: String] {
        let resources = try #require(Bundle.main.resourceURL)
        let file = resources.appending(path: "\(language).lproj/\(table).strings")
        let data = try Data(contentsOf: file)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(propertyList as? [String: String])
    }

    private func placeholders(in text: String) -> [String] {
        text.matches(of: /%(?:%|@|lld)?/).map { String($0.output) }
    }
}
