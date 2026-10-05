//
//  ContentView.swift
//  MyUniDay
//
//  Root application container view hosting the primary MainTabView navigation.
//

import SwiftUI

/// Root application view hosting `MainTabView`.
///
/// Obtains its dependencies from the composition root (`AppDependencyContainer`),
/// maintaining complete architectural decoupling from persistence details.
///
/// In development (`#if DEBUG`), it supports switching between an isolated in-memory demo dataset
/// and the live production store without contaminating persistent storage.
@MainActor
struct ContentView: View {
    #if DEBUG
    @State private var isDemoMode: Bool = true
    @State private var container: AppDependencyContainer = DevelopmentDemoData.makeDemoContainer()
    #else
    private let container: AppDependencyContainer = AppDependencyContainer.shared
    #endif

    var body: some View {
        #if DEBUG
        MainTabView(
            container: container,
            isDemoMode: isDemoMode,
            onSwitchMode: { useDemo in
                isDemoMode = useDemo
                if useDemo {
                    container = DevelopmentDemoData.makeDemoContainer()
                } else {
                    container = AppDependencyContainer.shared
                }
            }
        )
        .id(isDemoMode) // Ensures clean view recreation upon mode switch
        #else
        MainTabView(container: container)
        #endif
    }
}

#Preview {
    ContentView()
}
