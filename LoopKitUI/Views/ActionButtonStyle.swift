//
//  ActionButtonStyle.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct ActionButtonStyle: ButtonStyle {
    public enum ButtonType {
        case primary
        case secondary
        case destructive
    }

    private let fontColor: Color
    private let backgroundColor: Color
    private let edgeColor: Color
    private let cornerRadius: CGFloat = 14
    private let borderWidth: CGFloat = 1.5

    @Environment(\.isEnabled) private var isEnabled: Bool

    public init(_ style: ButtonType = .primary) {
        switch style {
        case .primary:
            fontColor = .white
            backgroundColor = .accentColor
            edgeColor = .clear
        case .destructive:
            fontColor = .white
            backgroundColor = .red
            edgeColor = .clear
        case .secondary:
            fontColor = .accentColor
            backgroundColor = .clear
            edgeColor = .accentColor
        }
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundColor(isEnabled ? fontColor : Color(.tertiaryLabel))
            .font(.headline)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isEnabled ? backgroundColor : Color(.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isEnabled ? edgeColor : .clear, lineWidth: borderWidth)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
