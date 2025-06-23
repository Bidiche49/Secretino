//
//  SecretinoApp.swift
//  Secretino
//
//  Point d'entrée principal de l'application
//

import SwiftUI

@main
struct SecretinoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // SwiftUI Scene vide car on utilise NSStatusItem pour la menu bar
        Settings {
            EmptyView()
        }
    }
}
