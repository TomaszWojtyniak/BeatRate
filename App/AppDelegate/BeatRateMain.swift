//
//  BeatRateMain.swift
//  BeatRate
//
//  Created by Tomasz Wojtyniak on 23/05/2025.
//

import AppRoot
import AppRootUI
import Composition
import CompositionLive
import SwiftUI
#if DEBUG
import IntrospectionKit
#endif

/// The iOS host: builds the root on the real SDKs and shows it. The CLI is the other host.
@main
struct BeatRateMain: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    /// Built in `init`, before `didFinishLaunching`: `Edges.live()` configures Firebase
    /// first, and the root starts loading at once.
    private let app: BeatRateApp
    #if DEBUG
    @State private var server: IntrospectionServer?
    #endif

    init() {
        app = BeatRateApp(edges: .live())
    }

    var body: some Scene {
        WindowGroup {
            RootView(navigator: app.navigator)
            #if DEBUG
                .task { startServer() }
            #endif
        }
    }

    #if DEBUG
    /// `nc localhost 7777` gives the same ls/do as the headless CLI, against the running app.
    private func startServer() {
        guard server == nil else { return }
        do {
            server = try IntrospectionServer(port: 7777, session: IntrospectionSession(root: app))
            server?.start()
        } catch {
            print("IntrospectionServer could not start: \(error)")
        }
    }
    #endif
}
