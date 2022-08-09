//
//  MIWSMessage.h
//  MIWireSessionMac
//
//  Created by BenArvin on 2020/11/18.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import <Foundation/Foundation.h>

/*
 msgDic:
 {
    type
    UDID
    cmd
    reqID
    data
    
    address
    device: {
        model
        name
        sysV
        scrSize
        scrScale
    }
 }
 */

static NSString *const kMIWSMessageKeyType = @"type";
static NSString *const kMIWSMessageKeyUDID = @"UDID";
static NSString *const kMIWSMessageKeyCmd = @"cmd";
static NSString *const kMIWSMessageKeyReqID = @"reqID";
static NSString *const kMIWSMessageKeyData = @"data";
static NSString *const kMIWSMessageKeyAddress = @"address";//device address(of this connection, not real)
static NSString *const kMIWSMessageKeyDeviceInfo = @"device";//device info
static NSString *const kMIWSMessageKeyDIModel = @"model";//device model
static NSString *const kMIWSMessageKeyDIName = @"name";//device name
static NSString *const kMIWSMessageKeyDISysVersion = @"sysV";//system version
static NSString *const kMIWSMessageKeyDIScreenSize = @"scrSize";//screen size
static NSString *const kMIWSMessageKeyDIScreenScale = @"scrScale";//screen scale

static NSString *const kMIWSMessageTypeReq = @"req";//request from iOS to mac
static NSString *const kMIWSMessageTypeRes = @"res";//mac response for request from iOS
static NSString *const kMIWSMessageTypePush = @"push";//push from mac to iOS, no need reply

typedef NS_ENUM(NSUInteger, MIWSMessageType) {
    MIWSMessageTypeSHF  = 1010,
    MIWSMessageTypeSHS  = 1011,
    MIWSMessageTypeSHT  = 1012,
    MIWSMessageTypePing = 1020,
    MIWSMessageTypePong = 1021,
    MIWSMessageTypeData = 1030,
};
