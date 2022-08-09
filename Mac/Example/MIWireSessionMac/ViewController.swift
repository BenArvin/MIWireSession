//
//  ViewController.swift
//  MIWireSessionMac
//
//  Created by BenArvin on 11/17/2020.
//  Copyright (c) 2020 BenArvin. All rights reserved.
//

import Cocoa

public class ViewController: MIWSEViewController {
    
    private var _session: MIWireSessionMac = MIWireSessionMac.init(port: 2371)
    
    private lazy var _logTextView: MIWSEScrollableTextView = {
        let result = MIWSEScrollableTextView.init()
        result.wantsLayer = true
        result.layer!.backgroundColor = NSColor.black.cgColor
        return result
    }()
    
    private lazy var _resTextView: MIWSEScrollableTextView = {
        let result = MIWSEScrollableTextView.init()
        result.wantsLayer = true
        result.layer!.backgroundColor = NSColor.black.cgColor
        return result
    }()
    
    private lazy var _inputTextView: NSTextView = {
        let result = NSTextView.init()
        result.wantsLayer = true
        result.layer!.backgroundColor = NSColor.black.cgColor
        result.drawsBackground = true
        result.textColor = NSColor.lightGray
        result.font = NSFont.systemFont(ofSize: 26)
        result.isAutomaticLinkDetectionEnabled = false
        result.usesFontPanel = false
        result.autoresizingMask = NSView.AutoresizingMask.width
        return result
    }()
    
    private lazy var _sendBtn: NSButton = {
        let result = NSButton.init(title: "send", target: self, action: #selector(_onSendBtnSelected(_:)))
        result.bezelStyle = NSButton.BezelStyle.regularSquare
        result.font = NSFont.systemFont(ofSize: 20)
        return result
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(_onDeviceAttachedNotification(_:)), name: Notification.Name(kMIWSMacNotificationDeviceAttached), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_onDeviceDetachedNotification(_:)), name: Notification.Name(kMIWSMacNotificationDeviceDetached), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_onDeviceConnectedNotification(_:)), name: Notification.Name(kMIWSMacNotificationDeviceConnected), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_onDeviceDisconnectedNotification(_:)), name: Notification.Name(kMIWSMacNotificationDeviceDisconnected), object: nil)
        self._session.setObserver("testReq", observer: self)
        self._session.setLogReceiver(self)
        self._session.start()
    }
    
    public override func viewWillAppear() {
        super.viewWillAppear()
        if self._logTextView.superview != self.view {
            self.view.addSubview(self._logTextView)
            self.view.addSubview(self._resTextView)
            self.view.addSubview(self._inputTextView)
            self.view.addSubview(self._sendBtn)
        }
    }
    
    public override func viewWillLayout() {
        super.viewWillLayout()
        self._setElementsFrame()
    }
}

extension ViewController: MIWireSessionMacObserverProtocol {
    public func wireSession(_ session: MIWireSessionMac!, onRequest UDID: String!, reqID: String!, cmd: String!, data: Data!) {
        var msgStr: String = "NULL"
        if data != nil {
            let strTmp = String.init(data: data!, encoding: .utf8)
            if strTmp != nil {
                msgStr = strTmp!
                self._printLog("Receive msg: ".appending(strTmp!))
            } else {
                self._printLog("Receive mull msg")
            }
        } else {
            self._printLog("Receive mull msg")
        }
        self._printRes(String.init(format:"Received request from %@, reqID=%@, cmd=%@, msgStr=%@", UDID, reqID, cmd, msgStr))
        session.response("testRes for ".appending(msgStr).data(using: .utf8), for: UDID, reqID: reqID) { [weak self] (error: Error?) in
            guard let strongSelf = self else {
                return
            }
            strongSelf._printRes(String.init(format:"Send response %@, desc: %@", error == nil ? "success" : "failed", error == nil ? "unknown" : error!.localizedDescription))
        }
    }
}

extension ViewController: MIWSLoggerReceiverProtocol {
    public func onWireSessionLog(_ log: String!) {
        self._printLog(log)
    }
}

extension ViewController {
    private func _setElementsFrame() {
        let logViewWidth = self.view.bounds.width - 20
        let logViewHeight = floor(self.view.bounds.height / 3)
        self._logTextView.frame = CGRect.init(x: 10, y: 10, width: logViewWidth, height: logViewHeight)
        self._resTextView.frame = CGRect.init(x: 10, y: self._logTextView.frame.maxY + 20, width: logViewWidth, height: logViewHeight)
        self._inputTextView.frame = CGRect.init(x: 100, y: self._resTextView.frame.maxY + 50, width: 300, height: 30)
        self._sendBtn.frame = CGRect.init(x: self._inputTextView.frame.maxX + 50, y: self._inputTextView.frame.minY, width: 80, height: 30)
    }
}

extension ViewController {
    @objc private func _onSendBtnSelected(_ sender: NSButton?) {
        let msg: String? = self._inputTextView.string
        if msg == nil || msg!.count == 0 {
            return
        }
        self._inputTextView.string = ""
        self._session.broadcast(msg!.data(using: .utf8), completion: { [weak self] (successed: Bool, brief: Error?, details: [String : Error]?) in
            guard let strongSelf = self else {
                return
            }
            if successed == true {
                strongSelf._printRes(String.init(format:"Send push success: %@", msg!))
            } else {
                strongSelf._printRes(String.init(format:"Send push failed: %@, desc: %@", msg!, brief == nil ? "unknown" : brief!.localizedDescription))
            }
        })
    }
    
    @objc private func _onDeviceAttachedNotification(_ notification: NSNotification!) {
        let userInfo = notification.userInfo
        if userInfo == nil {
            self._printRes("On device attached notification, userInfo is NULL")
            return
        }
        let UDID: String? = userInfo!["UDID"] as? String ?? nil
        if UDID == nil {
            self._printRes("On device attached notification, UDID is NULL")
            return
        }
        self._printRes(String.init(format:"Device attached: %@", UDID!))
    }
    
    @objc private func _onDeviceDetachedNotification(_ notification: NSNotification!) {
        let userInfo = notification.userInfo
        if userInfo == nil {
            self._printRes("On device detached notification, userInfo is NULL")
            return
        }
        let UDID: String? = userInfo!["UDID"] as? String ?? nil
        if UDID == nil {
            self._printRes("On device detached notification, UDID is NULL")
            return
        }
        self._printRes(String.init(format:"Device detached: %@", UDID!))
    }
    
    @objc private func _onDeviceConnectedNotification(_ notification: NSNotification!) {
        let userInfo = notification.userInfo
        if userInfo == nil {
            self._printRes("On device connected notification, userInfo is NULL")
            return
        }
        let UDID: String? = userInfo!["UDID"] as? String ?? nil
        if UDID == nil {
            self._printRes("On device connected notification, UDID is NULL")
            return
        }
        self._printRes(String.init(format:"✅ Device connected: %@", UDID!))
    }
    
    @objc private func _onDeviceDisconnectedNotification(_ notification: NSNotification!) {
        let userInfo = notification.userInfo
        if userInfo == nil {
            self._printRes("On device disconnected notification, userInfo is NULL")
            return
        }
        let UDID: String? = userInfo!["UDID"] as? String ?? nil
        if UDID == nil {
            self._printRes("On device disconnected notification, UDID is NULL")
            return
        }
        self._printRes(String.init(format:"❌ Device disconnected: %@", UDID!))
    }
}

extension ViewController {
    private func _printLog(_ log: String?) {
        if log == nil || log!.count == 0 {
            return
        }
        let attrStr = NSMutableAttributedString.init(string: "\n".appending(log!))
        attrStr.setAttributes([NSAttributedStringKey.font : NSFont.systemFont(ofSize: 12), NSAttributedStringKey.foregroundColor: NSColor.lightGray], range: NSRange.init(location: 0, length: attrStr.length))
        DispatchQueue.main.async { [weak self] in
        guard let strongSelf = self else {
                return
            }
            strongSelf._logTextView.appendAttrStr(attrStr)
            if strongSelf._logTextView.isAtBottom() == true {
                strongSelf._logTextView.scrollToBottom()
            }
        }
    }
    
    private func _printRes(_ log: String?) {
        if log == nil || log!.count == 0 {
            return
        }
        let attrStr = NSMutableAttributedString.init(string: "\n".appending(log!))
        attrStr.setAttributes([NSAttributedStringKey.font : NSFont.systemFont(ofSize: 12), NSAttributedStringKey.foregroundColor: NSColor.lightGray], range: NSRange.init(location: 0, length: attrStr.length))
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf._resTextView.appendAttrStr(attrStr)
            if strongSelf._resTextView.isAtBottom() == true {
                strongSelf._resTextView.scrollToBottom()
            }
        }
    }
}
