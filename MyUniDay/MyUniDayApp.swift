//
//  MyUniDayApp.swift
//  MyUniDay
//
//  Created by Vicky Neves Rohr on 2/10/2026.
//

import SwiftUI
import CoreData

@main
struct MyUniDayApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
