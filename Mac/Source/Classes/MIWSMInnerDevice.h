//
//  MIWSMInnerDevice.h
//  MIWireSessionMac
//
//  Created by BenArvin on 2020/11/17.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import <Foundation/Foundation.h>

@interface MIWSMInnerDevice : NSObject

@property (atomic) BOOL connected;
@property (atomic) BOOL connecting;
@property (nonatomic) NSInteger ID;
@property (nonatomic) NSString *UDID;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *sysVersion;
@property (nonatomic) NSString *screenSize;
@property (nonatomic) NSString *screenScale;
@property (atomic) NSInteger missedPing;
@property (atomic) NSInteger missedDeviceScan;

- (instancetype)initWithAttachNotification:(NSNotification *)notification;

+ (NSInteger)extractID:(NSNotification *)notification;

@end
