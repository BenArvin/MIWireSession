//
//  MIWSMInnerDevice.m
//  MIWireSessionMac
//
//  Created by BenArvin on 2020/11/17.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import "MIWSMInnerDevice.h"

static NSString *const kMIWSMInnerDeviceNotifiKeyProperties = @"Properties";
static NSString *const kMIWSMInnerDeviceNotifiKeyDeviceID = @"DeviceID";
static NSString *const kMIWSMInnerDeviceNotifiKeyUDID = @"SerialNumber";

@implementation MIWSMInnerDevice

- (instancetype)init {
    self = [super init];
    if (self) {
        _connected = NO;
        _missedPing = 0;
    }
    return self;
}

- (instancetype)initWithAttachNotification:(NSNotification *)notification {
    self = [self init];
    if (!self) {
        return self;
    }
    if (!notification || !notification.userInfo) {
        return self;
    }
    _ID = [[self class] extractID:notification];
    id properties = [notification.userInfo objectForKey:kMIWSMInnerDeviceNotifiKeyProperties];
    if ([properties isKindOfClass:[NSDictionary class]]) {
        _UDID = [(NSDictionary *)properties objectForKey:kMIWSMInnerDeviceNotifiKeyUDID];
    }
    return self;
}

+ (NSInteger)extractID:(NSNotification *)notification {
    if (!notification || !notification.userInfo) {
        return -1;
    }
    id deviceIDObj = [notification.userInfo objectForKey:kMIWSMInnerDeviceNotifiKeyDeviceID];
    if (![deviceIDObj isKindOfClass:[NSNumber class]]) {
        return -1;
    }
    return ((NSNumber *)deviceIDObj).integerValue;;
}

@end
