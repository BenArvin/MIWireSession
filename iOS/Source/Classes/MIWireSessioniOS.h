//
//  MIWireSessioniOS.h
//  Pods
//
//  Created by BenArvin on 2020/11/17.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import <Foundation/Foundation.h>
#import "MIWSLogger.h"

extern NSString *const kMIWireSessioniOSNotificationConnected;
extern NSString *const kMIWireSessioniOSNotificationDisconnected;
extern NSString *const kMIWireSessioniOSNotificationPushReceived;

extern NSString *const kMIWireSessioniOSNotificationKeyData;

@interface MIWireSessioniOS : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPort:(in_port_t)port;

- (void)setLogReceiver:(id <MIWSLoggerReceiverProtocol>)receiver;

- (void)start;
- (void)stop;
- (BOOL)isConnected;

- (void)request:(NSString *)cmd data:(NSData *)data completion:(void(^)(NSData *response, NSError *error))completion;
- (void)request:(NSString *)cmd data:(NSData *)data overtime:(NSInteger)overtime completion:(void(^)(NSData *response, NSError *error))completion;

@end
