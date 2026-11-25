//
//  MusicAccessStatus+MusicKit.swift
//  MusicKitServiceLive
//

#if os(iOS)
import MusicKit
import MusicKitService

extension MusicAccessStatus {
    nonisolated init(_ status: MusicAuthorization.Status) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .authorized: self = .authorized
        // A status MusicKit adds later is not a grant the app knows how to use.
        @unknown default: self = .denied
        }
    }
}
#endif
