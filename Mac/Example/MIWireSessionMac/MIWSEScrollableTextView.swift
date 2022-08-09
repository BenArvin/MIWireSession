//
//  MIWSEScrollableTextView.swift
//  MIWireSessionMac_Example
//
//  Created by BenArvin on 2020/12/2.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Cocoa

class MIWSEScrollableTextView: NSView {
    public lazy var scrollView: NSScrollView = {
        let result = NSScrollView.init()
        result.drawsBackground = false
        result.backgroundColor = NSColor.black
        result.hasVerticalScroller = true
        result.hasHorizontalScroller = false
        result.horizontalScrollElasticity = NSScrollView.Elasticity.none
        result.autohidesScrollers = true
        return result
    }()
    
    public lazy var textView: NSTextView = {
        let result = NSTextView.init()
        result.drawsBackground = false
        result.textColor = NSColor.lightGray
        result.font = NSFont.systemFont(ofSize: 12)
        result.isEditable = false
        result.isVerticallyResizable = true
        result.isHorizontallyResizable = false
        result.textContainer!.widthTracksTextView = true
        result.isAutomaticLinkDetectionEnabled = false
        result.usesFontPanel = false
        result.autoresizingMask = NSView.AutoresizingMask.width
        return result
    }()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.addSubview(self.textView)
        self.scrollView.documentView = self.textView
        self.addSubview(self.scrollView)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(self.textView)
        self.scrollView.documentView = self.textView
        self.addSubview(self.scrollView)
    }
    
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        self.textView.minSize = CGSize.init(width: self.bounds.width, height: self.bounds.height)
        self.textView.maxSize = CGSize.init(width: CGFloat(Float.greatestFiniteMagnitude), height: CGFloat(Float.greatestFiniteMagnitude))
        self.textView.textContainer!.containerSize = CGSize.init(width: CGFloat(Float.greatestFiniteMagnitude), height: CGFloat(Float.greatestFiniteMagnitude))
        self.scrollView.frame = CGRect.init(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
    }
}

extension MIWSEScrollableTextView {
    
    public func appendAttrStr(_ attrStr: NSAttributedString?) {
        if attrStr == nil {
            return
        }
        self.textView.textStorage!.append(attrStr!)
    }
    
    public func distanceToBottom() -> CGFloat {
        return self.textView.visibleRect.maxY - self.textView.bounds.maxY
    }
    
    public func isAtBottom() -> Bool {
        return (self.distanceToBottom() == 0)
    }
    
    public func scrollToBottom() {
        self.textView.scrollRangeToVisible(NSRange.init(location: self.textView.string.count, length: 0))
    }
}
