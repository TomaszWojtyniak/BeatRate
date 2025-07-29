//
//  SetHomeUseCase.swift
//  HomeUseCases
//
//  Created by Tomasz Wojtyniak on 30/06/2025.
//

import SwiftUI
import MusicKitService

public protocol SetHomeUseCaseProtocol: Sendable {
    
}

public actor SetHomeUseCase: SetHomeUseCaseProtocol {
    private let musicKitService: MusicKitServiceProtocol
    
    public init(musicKitService: MusicKitServiceProtocol = MusicKitService.shared) {
        self.musicKitService = musicKitService
    }
}
