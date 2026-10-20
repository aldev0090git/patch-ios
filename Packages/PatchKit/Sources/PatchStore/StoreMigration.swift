import Foundation

/// Moves the SwiftData store into the App Group, so an extension can write.
///
/// The widget gets by on a snapshot file because it only reads. A Control
/// Centre control has to *log*, and its intent runs in the extension process,
/// which cannot reach the app's own container at all. The store has to move.
///
/// ## Why a file copy rather than reading and re-writing the data
///
/// The obvious migration — open the old container, read everything, write it
/// into a new one — needs two `ModelContainer`s alive at once, and this
/// project has already been bitten by that: the second one in a process traps
/// with SIGTRAP, serialized or not. See the note in `SwiftDataGoalStoreTests`.
/// Copying the files happens before any container exists, so the question
/// never arises.
///
/// ## Why it cannot half-happen
///
/// A SQLite store is up to three files — the database and its `-wal` and
/// `-shm` sidecars — and the write-ahead log holds writes that are not in the
/// main file yet. Copying the database alone silently loses whatever was in
/// the log, and copying two of three and failing on the last would leave a
/// store that *looks* migrated and is missing recent days.
///
/// So the copy is staged in a sibling directory and the whole directory is
/// moved into place in one step. A rename within a volume either happens or
/// does not, which makes a partial migration unrepresentable rather than
/// merely unlikely.
///
/// ## Why the old file is never deleted
///
/// If anything throws, this returns the legacy URL and the app opens exactly
/// the store it opened yesterday — the failure mode is "the feature did not
/// arrive", not "the data is gone". The original stays on disk afterwards as
/// well. It costs a few hundred kilobytes and it is the difference between a
/// bad release being an inconvenience and being unrecoverable.
public enum StoreMigration {
    /// Where the store should live, migrating it there if it has not been yet.
    ///
    /// - Returns: the URL to open. The shared one when the move succeeded or
    ///   had already happened, the legacy one when anything went wrong.
    public static func resolveStoreURL(
        legacy: URL,
        sharedDirectory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let destination = sharedDirectory.appendingPathComponent(storeName)
        if fileManager.fileExists(atPath: destination.path) { return destination }

        let staging = sharedDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(sharedDirectory.lastPathComponent + "-staging")

        do {
            // Left behind by a migration that was interrupted — a crash, or
            // the phone running out of space. It is a partial copy by
            // definition and must never be mistaken for the real one.
            if fileManager.fileExists(atPath: staging.path) {
                try fileManager.removeItem(at: staging)
            }

            guard fileManager.fileExists(atPath: legacy.path) else {
                // Nothing to carry over: a fresh install starts in the right
                // place and never migrates at all.
                try fileManager.createDirectory(
                    at: sharedDirectory, withIntermediateDirectories: true
                )
                return destination
            }

            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            for url in companions(of: legacy) where fileManager.fileExists(atPath: url.path) {
                try fileManager.copyItem(
                    at: url,
                    to: staging.appendingPathComponent(
                        storeName + suffix(of: url, base: legacy)
                    )
                )
            }

            // The one irreversible step, and the only one that has to be
            // atomic. Everything before it wrote to a directory nothing reads.
            if fileManager.fileExists(atPath: sharedDirectory.path) {
                try fileManager.removeItem(at: sharedDirectory)
            }
            try fileManager.createDirectory(
                at: sharedDirectory.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.moveItem(at: staging, to: sharedDirectory)
            return destination
        } catch {
            try? fileManager.removeItem(at: staging)
            return legacy
        }
    }

    /// The name the store takes once it is shared. Deliberately not
    /// `default.store`: the two live in different places and a diagnostic
    /// naming one should never be ambiguous about which it meant.
    public static let storeName = "Patch.store"

    /// The database and its write-ahead log, which is where recent writes
    /// actually are until SQLite checkpoints them.
    private static func companions(of store: URL) -> [URL] {
        [store,
         URL(fileURLWithPath: store.path + "-wal"),
         URL(fileURLWithPath: store.path + "-shm")]
    }

    private static func suffix(of url: URL, base: URL) -> String {
        String(url.path.dropFirst(base.path.count))
    }
}

extension StoreMigration {
    /// The App Group container, or nil where the entitlement is missing.
    ///
    /// Only trustworthy on iOS. On macOS — which is where `swift test` runs —
    /// `containerURL(for:)` hands back a path for any identifier at all,
    /// entitlement or not, so this cannot be used to detect a misconfigured
    /// App Group from a unit test.
    public static func sharedDirectory(
        appGroup: String,
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("Store")
    }
}
