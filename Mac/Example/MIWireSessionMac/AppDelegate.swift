//
//  AppDelegate.swift
//  MIWireSessionMac
//
//  Created by BenArvin on 11/17/2020.
//  Copyright (c) 2020 BenArvin. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    public var rootVC: ViewController?
    public var window: NSWindow?
    public var rootWC: NSWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        self.rootVC = ViewController()
        self.window = NSWindow.init(contentViewController: self.rootVC!)
        
        let width: CGFloat = floor(NSScreen.main!.frame.width * 0.618)
        let height: CGFloat = floor(NSScreen.main!.frame.height * 0.618)
        self.window!.setFrame(NSRect.init(x: floor((NSScreen.main!.frame.width - width) / 2),
                                          y: floor((NSScreen.main!.frame.height - height) / 2),
                                          width: width,
                                          height: height),
                              display: true)
        self.window!.styleMask = [NSWindow.StyleMask.closable, NSWindow.StyleMask.miniaturizable, NSWindow.StyleMask.resizable, NSWindow.StyleMask.titled]
        self.window!.backingType = NSWindow.BackingStoreType.buffered
        self.window!.title = "NYXXcodePlugin"
        self.window!.delegate = self

        self.rootWC = NSWindowController.init(window: self.window!)
        self.rootWC!.showWindow(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
    }


}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        exit(0);
    }
}

// MARK: - main menu actions
extension AppDelegate {
    @objc func quitAction() {
        exit(0)
    }
}
