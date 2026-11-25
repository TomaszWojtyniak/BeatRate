//
//  FirebaseSetup.swift
//  FirebaseServiceLive
//

#if os(iOS)
import FirebaseCore
// TODO: Remove @preconcurrency when Firebase SDK adds Sendable support
@preconcurrency import FirebaseDatabase

/// Firebase as the app needs it before anything reads from it.
public enum FirebaseSetup {
    /// Configures Firebase and the offline cache of the Realtime Database. The app's root
    /// is built before `didFinishLaunching`, and its first effects read the database, so
    /// this runs first in `Edges.live()`. Persistence must be set before the first use.
    public static func configure(databaseURL: String) {
        FirebaseApp.configure()
        let database = Database.database(url: databaseURL)
        database.isPersistenceEnabled = true
        database.persistenceCacheSizeBytes = 10 * 1024 * 1024
    }
}
#endif
