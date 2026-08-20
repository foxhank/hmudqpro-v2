//
//  hmudqproApp.swift
//  hmudqpro
//
//  Created by foxhank on 2026/8/20.
//

import SwiftUI

@main
struct hmudqproApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
