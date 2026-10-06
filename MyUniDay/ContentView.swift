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

    @Environment(\.scenePhase) private var scenePhase

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
                Task {
                    try? await container.updateWidgetSnapshotUseCase.execute()
                }
            }
        )
        .id(isDemoMode) // Ensures clean view recreation upon mode switch
        .task {
            try? await container.updateWidgetSnapshotUseCase.execute()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active || newPhase == .background {
                Task {
                    try? await container.updateWidgetSnapshotUseCase.execute()
                }
            }
        }
        #else
        MainTabView(container: container)
            .task {
                try? await container.updateWidgetSnapshotUseCase.execute()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active || newPhase == .background {
                    Task {
                        try? await container.updateWidgetSnapshotUseCase.execute()
                    }
                }
            }
        #endif
    }
}

#Preview {
    ContentView()
}
