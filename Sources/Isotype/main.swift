import Foundation
import AppKit

// Forward declare app
//
_ = NSApplication.shared

// Map isomorphic layout from lowercase key character to offset
//
let root: UInt8 = 48
let offsets: [String: UInt8] = [
    "q": 10, "w": 11, "e": 12, "r": 13, "t": 14, "y": 15, "u": 16, "i": 17, "o": 18, "p": 19, "[": 20, "]": 21,
    "a": 05, "s": 06, "d": 07, "f": 08, "g": 09, "h": 10, "j": 11, "k": 12, "l": 13, ";": 14, "'": 15,
    "z": 00, "x": 01, "c": 02, "v": 03, "b": 04, "n": 05, "m": 06, ",": 07, ".": 08, "/": 09,
]

// Start SSH procss
let process = Process()
let pipe = Pipe()
process.executableURL = .init(fileURLWithPath: "/usr/bin/env")
process.arguments = [ "ssh", "pi@raspberrypi.local" ]
process.standardInput = pipe.fileHandleForReading
process.standardOutput = FileHandle.nullDevice
process.terminationHandler = { exit($0.terminationStatus) }
try! process.run()

// Build app menu
//
func build<T: NSObject>(callback: (T) -> ()) -> T {
    let subject = T()
    callback(subject)
    return subject
}
NSApp.mainMenu = build {
    $0.addItem(build {
        $0.submenu = build {
            $0.addItem(.init(title: "Hide Isotype", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
            $0.addItem(.init(title: "Quit Isotype", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        }
    })
}

// Add keyboard event listeners
//
NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
    guard event.modifierFlags.intersection([.control, .option, .command, .function]).isEmpty,
          let characters = event.characters,
          let offset = offsets[characters] else {
        return event
    }
    if event.isARepeat {
        // Consume repeated events, but don't send MIDI
        return nil
    }
    let note = String(format:"%02X", root + offset)
    let midi = event.type == .keyUp ? "80 \(note) 00" : "90 \(note) 7f"
    do {
        try pipe.fileHandleForWriting.write(contentsOf: "amidi -p hw:pisound -S '\(midi)'\n".data(using: .utf8)!)
    } catch(let error) {
        print("\(error), \(midi)")
    }
    return nil
}

// Workaround to make sure app starts with focus <https://stackoverflow.com/a/65763273>
//
@objc class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Start!
//
let delegate = Delegate()
NSApp.delegate = delegate
NSApp.run()
