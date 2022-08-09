//
//  MIWireSessioniOS.m
//  MIWireSessioniOS
//
//  Created by BenArvin on 2020/11/17.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import "MIWireSessioniOS.h"
#import "MIWSPTUSBHub.h"
#import "MIWSPTChannel.h"
#import "MIWSMessage.h"
#import "NSError+MIWSError.h"
#import "MIWSUtils.h"
#import "MIWSIRequestTask.h"
#import "MIWSUtils.h"

static const int kMIWireSessioniOSBuildConnectionOverTime = 5;

NSString *const kMIWireSessioniOSNotificationConnected = @"kMIWireSessioniOSNotificationConnected";
NSString *const kMIWireSessioniOSNotificationDisconnected = @"kMIWireSessioniOSNotificationDisconnected";
NSString *const kMIWireSessioniOSNotificationPushReceived = @"kMIWireSessioniOSNotificationPushReceived";
NSString *const kMIWireSessioniOSNotificationKeyData = @"data";

@interface MIWireSessioniOS() <MIWSPTChannelDelegate, MIWSIRequestTaskProtocol> {
}

@property (nonatomic) in_port_t port;
@property (atomic) BOOL running;
@property (atomic) BOOL connected;
@property (nonatomic) dispatch_queue_t actionQueue;
@property (nonatomic) dispatch_queue_t outputQueue;
@property (nonatomic) NSString *UDID;
@property (nonatomic) NSString *address;
@property (nonatomic) MIWSPTChannel *serverChannel;
@property (nonatomic) MIWSPTChannel *communicateChannel;
@property (nonatomic) NSMapTable *completions;
@property (nonatomic) NSMutableDictionary *tasks;

@end

@implementation MIWireSessioniOS

- (instancetype)init {
    self = [super init];
    if (self) {
        _actionQueue = dispatch_queue_create([NSString stringWithFormat:@"com.MIWireSessioniOS.actionQueue.%p", self].UTF8String, DISPATCH_QUEUE_SERIAL);
        _outputQueue = dispatch_queue_create([NSString stringWithFormat:@"com.MIWireSessioniOS.outputQueue.%p", self].UTF8String, DISPATCH_QUEUE_CONCURRENT);
        _UDID = nil;
        _connected = NO;
        _completions = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory];
        _tasks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithPort:(in_port_t)port {
    self = [self init];
    if (self) {
        _port = port;
    }
    return self;
}

#pragma mark - public methods
- (void)start {
    MIWSHighlightLog(@"Start SDK");
    self.running = YES;
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self innerStart];
    });
}

- (void)stop {
    MIWSHighlightLog(@"Stop SDK");
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self innerStop];
        self.running = NO;
    });
}

- (BOOL)isConnected {
    return self.connected;
}

- (void)request:(NSString *)cmd data:(NSData *)data completion:(void(^)(NSData *response, NSError *error))completion {
    [self request:cmd data:data overtime:kMIWSIRequestTaskOvertime completion:completion];
}

- (void)request:(NSString *)cmd data:(NSData *)data overtime:(NSInteger)overtime completion:(void(^)(NSData *response, NSError *error))completion {
    void(^onFinish)(NSString *reqID, NSData *response, NSError *error) = ^(NSString *reqID, NSData *response, NSError *error) {
        MIWSHighlightLog(@"Send request %@, reqID=%@, cmd=%@, desc: %@, reason: %@", error?@"Failed":@"Success", reqID, cmd, error?[error localizedDescription]:@"NULL", error?[error localizedFailureReason]:@"NULL");
        if (completion) {
            dispatch_async(self.outputQueue, ^{
                completion(response, error);
            });
        }
    };
    if (!cmd || cmd.length == 0) {
        onFinish(nil, nil, [NSError miws_errorWith:@"MIWireSessioniOS" code:10010 description:@"Send request failed, cmd can't be null" causes:nil]);
        return;
    }
    if (!self.connected) {
        onFinish(nil, nil, [NSError miws_errorWith:@"MIWireSessioniOS" code:10011 description:@"Send request failed, not connected" causes:nil]);
        return;
    }
    NSString *reqID = [self generateReqID];
    NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
    [msgDic setObject:kMIWSMessageTypeReq forKey:kMIWSMessageKeyType];
    [msgDic setObject:cmd forKey:kMIWSMessageKeyCmd];
    [msgDic setObject:reqID forKey:kMIWSMessageKeyReqID];
    [msgDic setObject:self.UDID forKey:kMIWSMessageKeyUDID];
    if (data) {
        [msgDic setObject:data forKey:kMIWSMessageKeyData];
    }
    dispatch_data_t payload = [msgDic createReferencingDispatchData];
    
    MIWSIRequestTask *task = [[MIWSIRequestTask alloc] init];
    task.delegate = self;
    task.overtime = overtime;
    task.cmd = cmd;
    task.reqID = reqID;
    task.completion = completion;
    
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        @miws_weak(self);
        [self.communicateChannel sendFrameOfType:MIWSMessageTypeData tag:MIWSPTFrameNoTag withPayload:payload callback:^(NSError *sendFrameError) {
            @miws_strong(self);
            if (sendFrameError) {
                onFinish(reqID, nil, [NSError miws_errorWith:@"MIWireSessioniOS" code:10012 description:@"Send request failed" causes:sendFrameError, nil]);
            } else {
                MIWSHighlightLog(@"Send request success, reqID=%@, cmd=%@, waiting for response", reqID, cmd);
                [self.tasks setObject:task forKey:reqID];
                [task start];
            }
        }];
    });
}

- (void)setLogReceiver:(id <MIWSLoggerReceiverProtocol>)receiver {
    [MIWSLogger setReceiver:receiver];
}

#pragma mark - PTChannelDelegate
- (void)ioFrameChannel:(MIWSPTChannel *)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(MIWSPTData *)payload {
    MIWSLowProfileLog(@"Receive msg of type %d", type);
    NSDictionary *msgDic = [NSDictionary dictionaryWithContentsOfDispatchData:payload.dispatchData];
    if (type == MIWSMessageTypeSHS) {
        [self onShakeHandSecondMsgReceived:msgDic tag:tag];
    } else if (type == MIWSMessageTypeData) {
        [self onDataReceived:msgDic];
    } else if (type == MIWSMessageTypePing) {
        [self onPingReceived:msgDic tag:tag];
    }
}

- (BOOL)ioFrameChannel:(MIWSPTChannel *)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    if (channel != self.communicateChannel) {
        MIWSLog(@"Can't accept frame of unknown channel, size=%d", payloadSize);
        return NO;
    } else {
        return YES;
    }
}

- (void)ioFrameChannel:(MIWSPTChannel *)channel didEndWithError:(NSError *)error {
    MIWSLog(@"Channel did end with error: %@, reason: %@", [error localizedDescription], [error localizedFailureReason]);
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self tryReconnect];
    });
}

- (void)ioFrameChannel:(MIWSPTChannel*)channel didAcceptConnection:(MIWSPTChannel*)otherChannel fromAddress:(MIWSPTAddress *)address {
    NSString *addressStr = [NSString stringWithFormat:@"%@:%ld", address.name, address.port];
    MIWSLog(@"Did accept connection from %@", addressStr);
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        self.address = addressStr;
        self.communicateChannel = otherChannel;
        
        NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
        [msgDic setObject:self.address forKey:kMIWSMessageKeyAddress];
        dispatch_data_t payload = [msgDic createReferencingDispatchData];
        [self.communicateChannel sendFrameOfType:MIWSMessageTypeSHF tag:MIWSPTFrameNoTag withPayload:payload callback:^(NSError *error) {
            MIWSLog(@"Send first shake hand msg %@, desc: %@, reason: %@", error?@"Failed":@"Success", [error localizedDescription], [error localizedFailureReason]);
        }];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kMIWireSessioniOSBuildConnectionOverTime * NSEC_PER_SEC)), self.actionQueue, ^{
        @miws_strong(self);
        if (self.connected) {
            MIWSLog(@"First shake hand msg overtime check success");
            return;
        }
        MIWSLog(@"First shake hand msg overtime check failed, try reconnect");
        [self tryReconnect];
    });
}

#pragma mark - MIWSIRequestTaskProtocol
- (void)onRequestTaskOvertime:(MIWSIRequestTask *)task {
    MIWSHighlightLog(@"On request task overtime, reqID=%@", task.reqID);
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self.tasks removeObjectForKey:task.reqID];
        if (task.completion) {
            task.completion(nil, [NSError miws_errorWith:@"MIWireSessioniOS" code:10050 description:@"Send request failed, task overtime" causes:nil]);
        } else {
            MIWSLog(@"On request task overtime, reqID=%@, completion is NULL", task.reqID);
        }
    });
}

#pragma mark - private methods
#pragma mark connection methods
- (void)innerStart {
    MIWSHighlightLog(@"SDK inner start");
    self.serverChannel = [MIWSPTChannel channelWithDelegate:self];
    [self.serverChannel listenOnPort:self.port IPv4Address:INADDR_LOOPBACK callback:^(NSError *error) {
        MIWSLog(@"SDK inner start, listen on port %@, desc: %@, reason: %@", error?@"Failed":@"Success", [error localizedDescription], [error localizedFailureReason]);
    }];
}

- (void)innerStop {
    MIWSHighlightLog(@"SDK inner stop");
    [self.serverChannel close];
    self.serverChannel = nil;
    [self.communicateChannel close];
    self.communicateChannel = nil;
    if (self.connected) {
        self.connected = NO;
        [self sendOnDisconnectedNotification];
    }
    [self failedAllTaskByDisconnect];
}

- (void)tryReconnect {
    MIWSHighlightLog(@"Try reconnect");
    [self innerStop];
    if (self.running) {
        MIWSLog(@"SDK still running, try reconnect");
        [self innerStart];
    } else {
        MIWSLog(@"SDK still stopped, do nothing");
    }
}

#pragma mark shake hand methods
- (void)onShakeHandSecondMsgReceived:(NSDictionary *)msgDic tag:(uint32_t)tag {
    NSString *address = [msgDic objectForKey:kMIWSMessageKeyAddress];
    NSString *UDID = [msgDic objectForKey:kMIWSMessageKeyUDID];
    MIWSLog(@"On second shake hand msg received, address=%@, UDID=%@", address, UDID);
    if (!address) {
        return;
    }
    if (!UDID) {
        return;
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        if (![self.address isEqualToString:address]) {
            MIWSLog(@"On second shake hand msg received, address is not equal, self address=%@", self.address);
            return;
        }
        self.UDID = UDID;
        
        NSMutableDictionary *deviceInfoDic = [[NSMutableDictionary alloc] init];
        
        UIDevice *device = [UIDevice currentDevice];
        [deviceInfoDic setObject:device.name?:@"Unknown" forKey:kMIWSMessageKeyDIName];
        [deviceInfoDic setObject:device.localizedModel forKey:kMIWSMessageKeyDIModel];
        [deviceInfoDic setObject:device.systemVersion forKey:kMIWSMessageKeyDISysVersion];
        
        UIScreen *screen = [UIScreen mainScreen];
        [deviceInfoDic setObject:NSStringFromCGSize(screen.bounds.size) forKey:kMIWSMessageKeyDIScreenSize];
        [deviceInfoDic setObject:[NSString stringWithFormat:@"%f", screen.scale] forKey:kMIWSMessageKeyDIScreenScale];
        
        NSMutableDictionary *newMsgDic = [[NSMutableDictionary alloc] init];
        [newMsgDic setObject:UDID forKey:kMIWSMessageKeyUDID];
        [newMsgDic setObject:deviceInfoDic forKey:kMIWSMessageKeyDeviceInfo];
        
        dispatch_data_t payload = [newMsgDic createReferencingDispatchData];
        [self.communicateChannel sendFrameOfType:MIWSMessageTypeSHT tag:tag withPayload:payload callback:^(NSError *error) {
            if (error) {
                MIWSLog(@"Send third shake hand msg failed, desc: %@, reason: %@", [error localizedDescription], [error localizedFailureReason]);
            } else {
                MIWSLog(@"Send third shake hand msg success");
                if (!self.connected) {
                    self.connected = YES;
                    [self sendOnConnectedNotification];
                }
            }
        }];
    });
}

#pragma mark ping pong methods
- (void)onPingReceived:(NSDictionary *)msgDic tag:(uint32_t)tag {
    NSString *UDID = [msgDic objectForKey:kMIWSMessageKeyUDID];
    MIWSLowProfileLog(@"On ping msg received, UDID=%@", UDID);
    if (!UDID) {
        return;
    }
    
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        dispatch_data_t payload = [msgDic createReferencingDispatchData];
        [self.communicateChannel sendFrameOfType:MIWSMessageTypePong tag:tag withPayload:payload callback:^(NSError *error) {
            MIWSLowProfileLog(@"Send pong msg %@, desc: %@, reason: %@", error?@"Failed":@"Success", [error localizedDescription], [error localizedFailureReason]);
        }];
    });
}

#pragma mark on data msg received
- (void)onDataReceived:(NSDictionary *)msgDic {
    NSString *UDID = [msgDic objectForKey:kMIWSMessageKeyUDID];
    NSString *reqID = [msgDic objectForKey:kMIWSMessageKeyReqID];
    NSString *type = [msgDic objectForKey:kMIWSMessageKeyType];
    MIWSLog(@"On data msg received, type=%@, UDID=%@, reqID=%@", type, UDID, reqID);
    if (!UDID || ![UDID isEqualToString:self.UDID]) {
        MIWSLog(@"On data msg received, type=%@, UDID=%@, reqID=%@, UDID not equal", type, UDID, reqID);
        return;
    }
    NSData *msgData = [msgDic objectForKey:kMIWSMessageKeyData];
    if ([type isEqualToString:kMIWSMessageTypeRes]) {
        if (!reqID || reqID.length == 0) {
            return;
        }
        [self onResponseReceived:reqID response:msgData];
    } else if ([type isEqualToString:kMIWSMessageTypePush]) {
        [self onPushReceived:msgData];
    }
}

- (void)onResponseReceived:(NSString *)reqID response:(NSData *)response {
    MIWSHighlightLog(@"On response for %@ received", reqID);
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        MIWSIRequestTask *task = [self.tasks objectForKey:reqID];
        if (task) {
            if (task.running) {
                [task stop];
                [self.tasks removeObjectForKey:reqID];
                if (task.completion) {
                    MIWSHighlightLog(@"On response for %@ received, call completion", reqID);
                    dispatch_async(self.outputQueue, ^{
                        task.completion(response, nil);
                    });
                } else {
                    MIWSHighlightLog(@"On response for %@ received, completion is NULL", reqID);
                }
            } else {
                MIWSHighlightLog(@"On response for %@ received, task already stopped", reqID);
            }
        } else {
            MIWSHighlightLog(@"On response for %@ received, can't find task record", reqID);
        }
    });
}

- (void)onPushReceived:(NSData *)data {
    if (!data) {
        MIWSHighlightLog(@"On push received, data is NULL");
        return;
    }
    MIWSHighlightLog(@"On push received, data size=%ld", data.length);
    @miws_weak(self);
    dispatch_async(self.outputQueue, ^{
        @miws_strong(self);
        [[NSNotificationCenter defaultCenter] postNotificationName:kMIWireSessioniOSNotificationPushReceived object:self userInfo:@{kMIWireSessioniOSNotificationKeyData: data}];
    });
}

#pragma mark notification methods
- (void)sendOnConnectedNotification {
    MIWSHighlightLog(@"Connected");
    @miws_weak(self);
    dispatch_async(self.outputQueue, ^{
        @miws_strong(self);
        [[NSNotificationCenter defaultCenter] postNotificationName:kMIWireSessioniOSNotificationConnected object:self userInfo:nil];
    });
}

- (void)sendOnDisconnectedNotification {
    MIWSHighlightLog(@"Disconnected");
    @miws_weak(self);
    dispatch_async(self.outputQueue, ^{
        @miws_strong(self);
        [[NSNotificationCenter defaultCenter] postNotificationName:kMIWireSessioniOSNotificationDisconnected object:self userInfo:nil];
    });
}

#pragma mark task methods
- (void)failedAllTaskByDisconnect {
    MIWSLog(@"Failed all tasks, because of disconnect");
    [self.tasks enumerateKeysAndObjectsUsingBlock:^(NSString *reqID, MIWSIRequestTask *task, BOOL * _Nonnull stop) {
        if (task.completion) {
            task.completion(nil, [NSError miws_errorWith:@"MIWireSessioniOS" code:10060 description:@"Send request failed, disconnected" causes:nil]);
        }
    }];
    [self.tasks removeAllObjects];
}

#pragma mark others
- (NSString *)generateReqID {
    NSString *fullStr = [NSString stringWithFormat:@"%@_%.9f", [MIWSUtils UUID], [[NSDate date] timeIntervalSince1970]];
    return [MIWSUtils md5Str:fullStr];
}

@end
