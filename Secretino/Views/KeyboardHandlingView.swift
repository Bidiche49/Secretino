//
//  KeyboardShortcutHandler.swift
//  Gestionnaire de raccourcis clavier pour Secretino
//

import SwiftUI
import Cocoa

struct KeyboardShortcutHandler: NSViewRepresentable {
    let onCopy: () -> Void
    let onPaste: () -> Void
    
    func makeNSView(context: Context) -> KeyboardHandlerView {
        let view = KeyboardHandlerView()
        view.onCopy = onCopy
        view.onPaste = onPaste
        return view
    }
    
    func updateNSView(_ nsView: KeyboardHandlerView, context: Context) {
        nsView.onCopy = onCopy
        nsView.onPaste = onPaste
    }
}

class KeyboardHandlerView: NSView {
    var onCopy: (() -> Void)?
    var onPaste: (() -> Void)?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        
        // Détecter Command+C et Command+V
        if modifiers.contains(.command) && !modifiers.contains(.shift) && !modifiers.contains(.option) {
            switch key {
            case "c":
                print("🎯 Raccourci ⌘+C détecté - Copier")
                onCopy?()
                return
            case "v":
                print("🎯 Raccourci ⌘+V détecté - Coller & Traiter")
                onPaste?()
                return
            default:
                break
            }
        }
        
        // Passer l'événement au suivant si non géré
        super.keyDown(with: event)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Devenir first responder quand ajouté à la fenêtre
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
        }
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow != nil {
            DispatchQueue.main.async {
                newWindow?.makeFirstResponder(self)
            }
        }
    }
}
