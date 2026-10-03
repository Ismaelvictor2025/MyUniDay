//
//  ContentView.swift
//  MyUniDay
//
//  Root application container view hosting the MyUniDay Dashboard.
//

import SwiftUI

/// Root application view hosting the main `DashboardView`.
///
/// Obtains its `DashboardViewModel` from the composition root (`AppDependencyContainer`),
/// maintaining complete architectural decoupling from persistence details.
///
/// In development (`#if DEBUG`), it supports switching between an isolated in-memory demo dataset
/// and the live production store without contaminating persistent storage.
@MainActor
struct ContentView: View {
    @State private var viewModel: DashboardViewModel
    #if DEBUG
    @State private var isDemoMode: Bool = true
    #endif

    init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    init() {
        #if DEBUG
        // Default to demo mode in debug so the simulator shows populated dashboard immediately!
        _viewModel = State(initialValue: DevelopmentDemoData.makeDemoViewModel())
        #else
        _viewModel = State(initialValue: AppDependencyContainer.shared.makeDashboardViewModel())
        #endif
    }

    var body: some View {
        #if DEBUG
        DashboardView(
            viewModel: viewModel,
            isDemoMode: isDemoMode,
            onSwitchMode: { useDemo in
                isDemoMode = useDemo
                if useDemo {
                    viewModel = DevelopmentDemoData.makeDemoViewModel()
                } else {
                    viewModel = AppDependencyContainer.shared.makeDashboardViewModel()
                }
                Task {
                    await viewModel.loadDashboard()
                }
            }
        )
        #else
        DashboardView(viewModel: viewModel)
        #endif
    }
}

#Preview {
    ContentView()
}
