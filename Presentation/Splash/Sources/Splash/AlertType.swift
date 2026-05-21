//
//  AlertType.swift
//  Splash
//

enum AlertType: Identifiable {
    case connectionError
    case musicKitDenied
    case spotifyReconnect

    var id: String {
        switch self {
        case .connectionError: "connectionError"
        case .musicKitDenied: "musicKitDenied"
        case .spotifyReconnect: "spotifyReconnect"
        }
    }
}
