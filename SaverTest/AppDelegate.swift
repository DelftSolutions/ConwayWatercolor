//
//  AppDelegate.swift
//
//  Created by Mirko Fetter on 25.10.16.
//  Copyright © 2016 grugru. All rights reserved.
//

// Test App for debugging the ScreenSaverView Code in Xcode

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    lazy var screenSaverView = ConwayWatercolorView(frame: NSZeroRect, isPreview: false)
    lazy var sheetController: ConfigureSheetController = ConfigureSheetController()

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        screenSaverView.inConfig = false
        screenSaverView.frame = (window.contentView?.bounds)!
        window.contentView?.addSubview(screenSaverView)
        screenSaverView.autoresizingMask = [.width, .height]
        //screenSaverView.startAnimation()
        
        let objects = objectsFromNib(loadNibNamed: "ConfigureSheet")

        // We need to find the correct window in our nib
        let object = objects.first { object in
            if let window = object as? NSWindow, window.identifier?.rawValue == "ConwayWatercolor" {
                return true
            }
            return false
        }

        if let window = object as? NSWindow {
            setUp(preferencesWindow: window)
        }
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func objectsFromNib(loadNibNamed nibName: String) -> [AnyObject] {
        var topLevelObjects: NSArray? = NSArray()

        _ =  Bundle.main.loadNibNamed(nibName, owner: sheetController,
                                      topLevelObjects: &topLevelObjects)

        return topLevelObjects! as [AnyObject]
    }
    
    private func setUp(preferencesWindow window: NSWindow) {
        window.makeKeyAndOrderFront(self)
        window.styleMask = [.closable, .titled, .miniaturizable]

        var frame = window.frame
        frame.origin = window.frame.origin
        window.setFrame(frame, display: true)
    }
}

