# MIWireSession

[![CI Status](https://img.shields.io/travis/BenArvin/MIWireSession.svg?style=flat)](https://travis-ci.org/BenArvin/MIWireSession)
[![Version](https://img.shields.io/cocoapods/v/MIWireSession.svg?style=flat)](https://cocoapods.org/pods/MIWireSession)
[![License](https://img.shields.io/cocoapods/l/MIWireSession.svg?style=flat)](https://cocoapods.org/pods/MIWireSession)
[![Platform](https://img.shields.io/cocoapods/p/MIWireSession.svg?style=flat)](https://cocoapods.org/pods/MIWireSession)

MIWireSession is an iOS and Mac Cocoa library for communicating over USB, with HTTP style API, based on [peertalk](https://github.com/rsms/peertalk).

## Features
- [x] selfdefine connection port
- [x] listening iOS device attach/dettach event, and connect/disconnect event
- [x] send request from iOS to Mac, or from Mac to iOS
- [x] boardcast message to all iOS devices from Mac

## Installation

MIWireSession is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
# pod library for iOS project
pod 'MIWireSessioniOS'

# pod library for Mac project
pod 'MIWireSessionMac'
```

## Author
BenArvin, benarvin93@outlook.com

## License
MIWireSession is available under the MIT license. See the LICENSE file for more info.
