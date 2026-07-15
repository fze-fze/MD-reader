import Foundation

enum DocumentRenamer {
    nonisolated static func isValidName(_ proposedName: String) -> Bool {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name != "." && name != ".." && !name.contains("/")
    }

    nonisolated static func rename(fileAt sourceURL: URL, to proposedName: String) throws -> URL {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidName(trimmedName) else {
            throw renameError(L10n.string("document.error.invalid_name"))
        }

        let pathExtension = sourceURL.pathExtension
        let baseName = removingExtension(pathExtension, from: trimmedName)
        let destinationURL = sourceURL
            .deletingLastPathComponent()
            .appending(path: baseName)
            .appendingPathExtension(pathExtension)

        guard destinationURL.standardizedFileURL != sourceURL.standardizedFileURL else {
            return sourceURL
        }
        guard !FileManager.default.fileExists(atPath: destinationURL.path()) else {
            throw renameError(
                L10n.format("document.error.name_exists", destinationURL.lastPathComponent)
            )
        }

        let didAccessSecurityScopedResource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScopedResource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var moveError: (any Error)?
        coordinator.coordinate(
            writingItemAt: sourceURL,
            options: .forMoving,
            writingItemAt: destinationURL,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedSourceURL, coordinatedDestinationURL in
            do {
                try FileManager.default.moveItem(
                    at: coordinatedSourceURL,
                    to: coordinatedDestinationURL
                )
                coordinator.item(
                    at: coordinatedSourceURL,
                    didMoveTo: coordinatedDestinationURL
                )
            } catch {
                moveError = error
            }
        }

        if let error = moveError ?? coordinationError {
            throw error
        }
        return destinationURL
    }

    nonisolated private static func removingExtension(
        _ pathExtension: String,
        from proposedName: String
    ) -> String {
        guard !pathExtension.isEmpty,
              proposedName.lowercased().hasSuffix(".\(pathExtension.lowercased())") else {
            return proposedName
        }
        return String(proposedName.dropLast(pathExtension.count + 1))
    }

    nonisolated private static func renameError(_ message: String) -> NSError {
        NSError(
            domain: "com.fze.margin.rename",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
