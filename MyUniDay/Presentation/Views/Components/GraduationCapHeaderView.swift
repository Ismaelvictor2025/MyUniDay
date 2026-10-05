//
//  GraduationCapHeaderView.swift
//  MyUniDay
//
//  Animated branded header featuring the floating graduation cap, app identity,
//  and contextual greeting, with strict respect for Reduce Motion accessibility.
//

import SwiftUI

public struct GraduationCapHeaderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isFloating: Bool = false
    @State private var isTilted: Bool = false

    public init() {}

    private var contextualGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date()).uppercased()
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Animated Graduation Cap Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 225/255, green: 235/255, blue: 248/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)

                Circle()
                    .stroke(
                        Color.white.opacity(0.6),
                        lineWidth: 1.5
                    )
                    .frame(width: 82, height: 82)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.black)
                    .offset(y: (!reduceMotion && isFloating) ? -4 : 4)
                    .rotationEffect(.degrees((!reduceMotion && isTilted) ? 3.5 : -3.5))
                    .scaleEffect((!reduceMotion && isFloating) ? 1.03 : 0.97)
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("MyUniDay graduation cap")
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 2.2)
                    .repeatForever(autoreverses: true)
                ) {
                    isFloating.toggle()
                }

                withAnimation(
                    .easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isTilted.toggle()
                }
            }

            // Brand Typography & Tagline
            VStack(spacing: 4) {
                Text(formattedDate)
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundStyle(Color(red: 175/255, green: 205/255, blue: 255/255))
                    .tracking(1.4)

                Text("MyUniDay")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Your university, organised.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(red: 215/255, green: 228/255, blue: 250/255))

                Text("\(contextualGreeting), here's your overview")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(red: 240/255, green: 245/255, blue: 255/255))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 16/255, green: 28/255, blue: 58/255), // Dark Navy
                    Color(red: 25/255, green: 45/255, blue: 90/255)  // Deep Royal Blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color(red: 10/255, green: 18/255, blue: 40/255).opacity(0.35), radius: 10, x: 0, y: 5)
    }
}
