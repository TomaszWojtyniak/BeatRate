//
//  AnalyticsKeys.swift
//  Analytics
//
//  Created by Tomasz Wojtyniak on 28/05/2025.
//

import SwiftUI
import FirebaseAnalytics
import OSLog

public protocol AnalyticsEvent: Sendable {
    var name: String { get }
    var parameters: [String: Any]? { get }
}

public enum AppAnalyticsEvent: AnalyticsEvent {
    case screenView(screenName: String, screenClass: String? = nil)
    case buttonTap(buttonName: String, location: String? = nil)
    case custom(eventName: String, parameters: [String: String]? = nil)
    
    public var name: String {
        switch self {
        case .screenView:
            return AnalyticsEventScreenView
        case .buttonTap:
            return "button_tap"
        case .custom(let eventName, _):
            return eventName
        }
    }
    
    public var parameters: [String: Any]? {
        switch self {
        case .screenView(let screenName, let screenClass):
            var params: [String: Any] = [AnalyticsParameterScreenName: screenName]
            if let screenClass = screenClass {
                params[AnalyticsParameterScreenClass] = screenClass
            }
            return params
        case .buttonTap(let buttonName, let location):
            var params: [String: Any] = ["button_name": buttonName]
            if let location = location {
                params["location"] = location
            }
            return params
        case .custom(_, let parameters):
            return parameters
        }
    }
}
