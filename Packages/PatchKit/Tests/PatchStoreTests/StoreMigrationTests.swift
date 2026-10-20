import Foundation
import Testing
@testable import PatchStore

/// The migration is the riskiest change in the app: it moves the file every
/// goal and every entry lives in. These tests exist to make the bad outcomes
/// unreachable rather than unlikely, so they are mostly about failure.
@Suite("Moving the store into the App Group")
struct StoreMigrationTests {
    /// A real directory in a temporary place. The migration is about files —
    /// faking `FileManager` would only test the fake.
    private func sandbox() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("patch-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeStore(
        at url: URL,
        contents: String = "database",
        wal: String? = "write-ahead log",
        shm: String? = "shared memory"
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
        if let wal {
            try wal.write(to: URL(fileURLWithPath: url.path + "-wal"),
                          atomically: true, encoding: .utf8)
        }
        if let shm {
            try shm.write(to: URL(fileURLWithPath: url.path + "-shm"),
                          atomically: true, encoding: .utf8)
        }
    }

    private func read(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - The happy path

    @Test("An existing store is copied into the shared directory and used from there")
    func migratesAnExistingStore() throws {
        let root = try sandbox()
        let legacy = root.appendingPathComponent("app/default.store")
        let shared = root.appendingPathComponent("group/Store")
        try writeStore(at: legacy, contents: "my goals")

        let resolved = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: shared)

        #expect(resolved == shared.appendingPathComponent("Patch.store"))
        #expect(read(resolved) == "my goals")
    }

    @Test("The write-ahead log travels with the database")
    func copiesTheSidecarFiles() throws {
        // The failure this prevents is the quiet one: SQLite keeps recent
        // writes in the -wal until it checkpoints, so a database copied
        // without its log opens successfully and is missing the last few days.
        let root = try sandbox()
        let legacy = root.appendingPathComponent("app/default.store")
        let shared = root.appendingPathComponent("group/Store")
        try writeStore(at: legacy, wal: "yesterday's entries", shm: "shm")

        let resolved = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: shared)

        #expect(read(URL(fileURLWithPath: resolved.path + "-wal")) == "yesterday's entries")
        #expect(read(URL(fileURLWithPath: resolved.path + "-shm")) == "shm")
    }

    @Test("A store with no sidecars migrates just as well")
    func sidecarsAreOptional() throws {
        let root = try sandbox()
        let legacy = root.appendingPathComponent("app/default.store")
        let shared = root.appendingPathComponent("group/Store")
        try writeStore(at: legacy, wal: nil, shm: nil)

        let resolved = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: shared)

        #expect(read(resolved) == "database")
        #expect(!FileManager.default.fileExists(atPath: resolved.path + "-wal"))
    }

    @Test("The original is left on disk, as a way back")
    func theLegacyStoreSurvives() throws {
        let root = try sandbox()
        let legacy = root.appendingPathComponent("app/default.store")
        let shared = root.appendingPathComponent("group/Store")
        try writeStore(at: legacy, contents: "my goals")

        _ = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: shared)

        #expect(read(legacy) == "my goals", "The only copy of the data was moved, not copied")
    }

    // MARK: - Running it again

    @Test("Running twice does not copy over what is already there")
    func isIdempotent() throws {
        let root = try sandbox()
        let legacy = root.appendingPathComponent("app/default.store")
        let shared = root.appendingPathComponent("group/Store")
        try writeStore(at: legacy, contents: "old")

        let first = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: shared)
        // Everything logged since the migration lives here now. A second run
        // that copied the legacy file again would throw all of it away.
        try "everything since".write(to: first, atomically: true, encoding: .utf8)

        let second = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: shared)

        #expect(second == first)
        #expect(read(second) == "everything since", "The migration ran twice and lost a day")
    }

    @Test("A fresh install starts in the shared directory without migrating")
    func freshInstall() throws {
        let root = try sandbox()
        let legacy = root.appendingPathComponent("app/default.store")
        let shared = root.appendingPathComponent("group/Store")

        let resolved = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: shared)

        #expect(resolved == shared.appendingPathComponent("Patch.store"))
        #expect(FileManager.default.fileExists(atPath: shared.path), "No directory to write into")
        #expect(!FileManager.default.fileExists(atPath: resolved.path), "Invented a store file")
    }

    // MARK: - When it goes wrong

    @Test("An interrupted migration leaves nothing that could be mistaken for the real store")
    func clearsStaleStaging() throws {
        // A crash or a full disk partway through leaves a half-copied
        // directory. Promoting that would be indistinguishable from data loss.
        let root = try sandbox()
        let legacy = root.appendingPathComponent("app/default.store")
        let shared = root.appendingPathComponent("group/Store")
        let staging = root.appendingPathComponent("group/Store-staging")
        try writeStore(at: legacy, contents: "my goals")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try "half a file".write(to: staging.appendingPathComponent("Patch.store"),
                                atomically: true, encoding: .utf8)

        let resolved = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: shared)

        #expect(read(resolved) == "my goals", "A partial copy was promoted")
        #expect(!FileManager.default.fileExists(atPath: staging.path), "Staging was left behind")
    }

    @Test("When the shared directory cannot be written, the app keeps its old store")
    func fallsBackToLegacy() throws {
        // Forced by making the *parent* of the shared directory a plain file,
        // so nothing can be created beneath it. The app must open yesterday's
        // store and carry on rather than start empty.
        //
        // A first attempt blocked the staging path itself, which proved
        // nothing: the migration deletes whatever is in its way there, by
        // design, so it cleaned up the obstacle and succeeded.
        let root = try sandbox()
        let legacy = root.appendingPathComponent("app/default.store")
        try writeStore(at: legacy, contents: "my goals")
        try "not a directory".write(to: root.appendingPathComponent("group"),
                                    atomically: true, encoding: .utf8)
        let blocked = root.appendingPathComponent("group/Store")

        let resolved = StoreMigration.resolveStoreURL(legacy: legacy, sharedDirectory: blocked)

        #expect(resolved == legacy, "A failed migration must not point at an empty store")
        #expect(read(resolved) == "my goals")
    }

    @Test("The shared store sits in its own directory, so the move can be one step")
    func sharedDirectoryIsAFolder() {
        // Not asserting nil for a bogus group: `containerURL(for:)` hands back
        // a path on macOS whether or not the entitlement exists, so a test for
        // that would be testing Foundation's host behaviour, not ours. What is
        // ours is the "Store" component — the migration renames that whole
        // directory into place, which is what makes it atomic.
        let url = StoreMigration.sharedDirectory(appGroup: "group.example.test")
        #expect(url == nil || url?.lastPathComponent == "Store")
    }
}
