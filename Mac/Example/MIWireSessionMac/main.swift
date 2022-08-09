//
//  main.swift
//  MIWireSessionMac
//
//  Created by BenArvin on 2020/12/2.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation

autoreleasepool {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    
    let firstMenu: NSMenu = NSMenu.init()
    firstMenu.addItem(NSMenuItem.init(title: "Quit", action: #selector(AppDelegate.quitAction), keyEquivalent: "q"))

    let firstMenuItem: NSMenuItem = NSMenuItem.init()
    firstMenuItem.submenu = firstMenu
    
    app.mainMenu = NSMenu.init()
    app.mainMenu!.addItem(firstMenuItem)
    
    app.run()
}
