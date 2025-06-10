//
//  Color+Extension.swift
//  CoreUI
//
//  Created by Tomasz Wojtyniak on 09/06/2025.
//

import SwiftUI

public extension Color {
    static let darkNavyBlue: Color = Color(red: 19/255, green: 31/255, blue: 51/255)
    static let creamBeige: Color = Color(red: 245/255, green: 225/255, blue: 200/255)
    static let goldenAmber: Color = Color(red: 212/255, green: 62/255, blue: 72/255)
    static let brickRed: Color = Color(red: 162/255, green: 31/255, blue: 51/255)
    static let pastelBlue: Color = Color(red: 142/255, green: 168/255, blue: 195/255)
    static let bottleGreen: Color = Color(red: 62/255, green: 98/255, blue: 89/255)
    static let deepIndigo: Color = Color(red: 45/255, green: 46/255, blue: 95/255)
    static let honeyYellow: Color = Color(red: 230/255, green: 182/255, blue: 85/255)
    static let lightGrey: Color = Color(red: 212/255, green: 212/255, blue: 212/255)
    static let crimsonRed: Color = Color(red: 178/255, green: 34/255, blue: 34/255)
    
    ///App uses of colors
    static let primaryText: Color = .creamBeige
    static let secondaryText: Color = .lightGrey
    static let errorRed: Color = .crimsonRed
    
    ///Gradients
    static let backgroundGradient = LinearGradient(colors: [Color(hex: "434C5E"), Color(hex: "131F33")], startPoint: .top, endPoint: .bottom)
}
