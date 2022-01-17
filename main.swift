import Foundation
import AppKit
import CoreMIDI
import SwiftMIDI

// Forward declare app
//
_ = NSApplication.shared

// Map isomorphic layout from lowercase key character to offset
//
let root: UInt8 = 48
let offsets: [String: UInt8] = [
    "q": 10, "w": 11, "e": 12, "r": 13, "t": 14, "y": 15, "u": 16, "i": 17, "o": 18, "p": 19,
    "a": 05, "s": 06, "d": 07, "f": 08, "g": 09, "h": 10, "j": 11, "k": 12, "l": 13, ";": 14,
    "z": 00, "x": 01, "c": 02, "v": 03, "b": 04, "n": 05, "m": 06, ",": 07, ".": 08, "/": 09,
]

// Setup device selection state
//
class Device: NSObject {
    static var all = [Device]()
    static var selected: MIDIEndpointRef? = nil
    static var menu: NSMenu? = nil

    let menuItem: NSMenuItem
    let endpoint: MIDIEndpointRef

    init(endpoint: MIDIEndpointRef, menuItem: NSMenuItem) {
        self.endpoint = endpoint
        self.menuItem = menuItem
    }

    @objc func select(_: Any? = nil) {
        for device in Device.all {
            device.menuItem.state = self == device ? .on : .off
        }
        Device.selected = self.endpoint
    }

    static func reset() {
        // Forget any existing devices
        while let device = Device.all.popLast() {
            device.menuItem.menu?.removeItem(device.menuItem)
        }
        // Query for latest destination list
        let destinations = SwiftMIDI.allDestinations
        // Create new devices and menu items
        for (i, endpoint) in destinations.enumerated() {
            guard let menu = Device.menu,
                  let name = try? SwiftMIDI.getStringProperty(object: endpoint, propertyID: "name") else {
                continue
            }
            let menuItem = NSMenuItem(title: name, action: #selector(Device.select(_:)), keyEquivalent: "\(i+1)")
            let device = Device(endpoint: endpoint, menuItem: menuItem)
            menuItem.target = device
            menu.insertItem(menuItem, at: i)
            Device.all.append(device)
        }
        // Forget selected device if it no longer exists
        if let selected = Device.selected, !destinations.contains(selected) {
            Device.selected = nil
        }
    }
}

// Initialize the Isotype MIDI client/port -- exit on failure
//
let client = try! SwiftMIDI.createClient(name: "Isotype") { _ in Device.reset() }
defer { try? SwiftMIDI.disposeClient(client) }
let port = try! SwiftMIDI.createOutputPort(clientRef: client, portName: "keyboard")

// Build MIDI device selection menu
//
func build<T: NSObject>(callback: (T) -> ()) -> T {
    let subject = T()
    callback(subject)
    return subject
}
NSApp.mainMenu = build {
    $0.addItem(build {
        $0.submenu = build { menu in
            Device.menu = menu
            menu.addItem(.separator())
            menu.addItem(.init(title: "Hide Isotype", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
            menu.addItem(.init(title: "Quit Isotype", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        }
    })
}
Device.reset()

// Add keyboard event listeners
//
NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
    guard event.modifierFlags.intersection([.control, .option, .command, .function]).isEmpty,
          let destination = Device.selected,
          let characters = event.characters,
          let offset = offsets[characters] else {
        return event
    }
    if event.isARepeat {
        // Consume repeated events, but don't send MIDI
        return nil
    }
    var packet = MIDIPacket()
    packet.data.0 = event.type == .keyUp ? 128 : 144
    packet.data.1 = root + offset
    packet.data.2 = event.type == .keyUp ? 0 : 127
    packet.length = 3
    packet.timeStamp = 0
    var packets = MIDIPacketList(numPackets: 1, packet: packet)
    if case .failure(let error) = Result(catching: { try SwiftMIDI.send(port: port, destination: destination, packetListPointer: &packets) }) {
        print("\(error), [\(packet.data.0), \(packet.data.1), \(packet.data.2)]")
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
