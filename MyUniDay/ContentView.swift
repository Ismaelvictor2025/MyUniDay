//
//  ContentView.swift
//  MyUniDay
//
//  Stage 1 placeholder view.
//

import SwiftUI

/// Stage 1 application entry view demonstrating architectural decoupling.
///
/// Views and ViewModels never directly interact with Core Data or NSManagedObject.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("MyUniDay")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Stage 1 — Domain Foundation")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Label("Domain Models Configured", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("Core Data Schema Configured", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("Repository Protocols Configured", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Label("Data Mappers Configured", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .font(.callout)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
