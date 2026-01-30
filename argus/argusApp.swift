//
//  argusApp.swift
//  argus
//
//  Created by Eren Kapak on 30.01.2026.
//

import SwiftUI
import CoreData

@main
struct argusApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
