import Foundation

enum SharedDataLocation {
    static let appGroupIdentifier: String = {
        Bundle.main.object(forInfoDictionaryKey: "LiuBaiAppGroup") as? String
            ?? "group.com.example.LiuBai.shared"
    }()

    static var legacyLibraryURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support
            .appendingPathComponent("LiuBai", isDirectory: true)
            .appendingPathComponent("library.json")
    }

    static func libraryURL(createDirectory: Bool = true) -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            if createDirectory {
                try? FileManager.default.createDirectory(
                    at: legacyLibraryURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
            }
            return legacyLibraryURL
        }

        let folder = container.appendingPathComponent("LibraryData", isDirectory: true)
        if createDirectory {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent("library.json")
    }

    static func migrateLegacyLibraryIfNeeded() {
        let destination = libraryURL()
        guard destination != legacyLibraryURL,
              !FileManager.default.fileExists(atPath: destination.path),
              FileManager.default.fileExists(atPath: legacyLibraryURL.path) else { return }
        try? FileManager.default.copyItem(at: legacyLibraryURL, to: destination)
    }
}
