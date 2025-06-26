//
//  HomeDataModel.swift
//  Home
//
//  Created by Tomasz Wojtyniak on 26/06/2025.
//

import SwiftUI
import Analytics
import OSLog
import Models

@Observable
@MainActor
class HomeDataModel {
    private let analyticsManager: AnalyticsManager
    private let crashLogger: CrashLogger
    static var logger: Logger {
        return Logger.for(Self.self)
    }
    
    var homeSections: [HomeSection] = [
        HomeSection(sectionName: "Popular", albums: [
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: "")
        ]),
        
        HomeSection(sectionName: "Popular", albums: [
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: "")
        ]),
        
        HomeSection(sectionName: "Popular", albums: [
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: "")
        ]),
        
        HomeSection(sectionName: "Popular", albums: [
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: "")
        ]),
        
        HomeSection(sectionName: "Popular", albums: [
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: "")
        ]),
        
        HomeSection(sectionName: "Popular", albums: [
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: "")
        ]),
        
        HomeSection(sectionName: "Popular", albums: [
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: "")
        ]),
        
        HomeSection(sectionName: "Popular", albums: [
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: ""),
            Album(title: "Until Dawn", artist: "The weekend", cover: "")
        ])
    ]
    
    init(analyticsManager: AnalyticsManager = .shared,
         crashLogger: CrashLogger = .shared) {
        self.analyticsManager = analyticsManager
        self.crashLogger = crashLogger
    }
}
