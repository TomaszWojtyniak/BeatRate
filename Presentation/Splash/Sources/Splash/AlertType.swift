//
//  AlertType.swift
//  Splash
//

enum AlertType: Identifiable {
    case connectionError
    case musicKitDenied

    var id: String {
        switch self {
        case .connectionError: "connectionError"
        case .musicKitDenied: "musicKitDenied"
        }
    }
}
