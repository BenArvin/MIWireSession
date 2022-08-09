//
//  MIWireSessionMac.m
//  MIWireSessionMac
//
//  Created by BenArvin on 2020/11/17.
//

#import "MIWireSessionMac.h"
#import "MIWSPTUSBHub.h"
#import "MIWSPTChannel.h"
#import "MIWSMInnerDevice.h"
#import "MIWSMessage.h"
#import "NSError+MIWSError.h"
#import "MIWSLogger.h"
#import "MIWSUtils.h"

NSString *const kMIWSMacNotificationDeviceAttached = @"kMIWSMacNotificationDeviceAttached";
NSString *const kMIWSMacNotificationDeviceDetached = @"kMIWSMacNotificationDeviceDetached";
NSString *const kMIWSMacNotificationDeviceConnected = @"kMIWSMacNotificationDeviceConnected";
NSString *const kMIWSMacNotificationDeviceDisconnected = @"kMIWSMacNotificationDeviceDisconnected";

static const int kMIWireSessionMacDeviceScanInterval = 1;
static const int kMIWireSessionMacPingInterval = 1;
static const int kMIWireSessionMacMissedPingLimit = 5;
static const int kMIWireSessionMacMissedDeviceScanLimit = 5;

@implementation MIWSDeviceInfo

- (instancetype)initWithInnerDevice:(MIWSMInnerDevice *)detail {
    self = [self init];
    if (self) {
        
    }
    return self;
}

@end

@interface MIWireSessionMac() <MIWSPTChannelDelegate> {
}

@property (nonatomic) in_port_t port;
@property (nonatomic) dispatch_queue_t actionQueue;
@property (nonatomic) dispatch_queue_t outputQueue;
@property (nonatomic) NSMapTable <NSString *, id<MIWireSessionMacObserverProtocol>> *observers;
@property (nonatomic) NSMutableDictionary <NSString *, MIWSMInnerDevice *> *devices;
@property (nonatomic) NSMutableDictionary <NSString *, MIWSPTChannel *> *channels;
@property (nonatomic) dispatch_source_t deviceScanTimer;
@property (nonatomic) dispatch_source_t pingTimer;
@property (nonatomic) NSMutableDictionary <NSString *, NSString *> *unResponsedReqIDs;

@end

@implementation MIWireSessionMac

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _observers = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory];
        _actionQueue = dispatch_queue_create([NSString stringWithFormat:@"com.MIWireSessionMac.actionQueue.%p", self].UTF8String, DISPATCH_QUEUE_SERIAL);
        _outputQueue = dispatch_queue_create([NSString stringWithFormat:@"com.MIWireSessionMac.outputQueue.%p", self].UTF8String, DISPATCH_QUEUE_CONCURRENT);
        _devices = [[NSMutableDictionary alloc] init];
        _channels = [[NSMutableDictionary alloc] init];
        _unResponsedReqIDs = [[NSMutableDictionary alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDeviceDidAttach:) name:MIWSPTUSBDeviceDidAttachNotification object:MIWSPTUSBHub.sharedHub];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDeviceDidDetach:) name:MIWSPTUSBDeviceDidDetachNotification object:MIWSPTUSBHub.sharedHub];
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
    MIWSHighlightLog(@"SDK start");
    MIWSHighlightLog(@"start device scan timmer");
    self.deviceScanTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.actionQueue);
    dispatch_source_set_timer(self.deviceScanTimer, DISPATCH_TIME_NOW, kMIWireSessionMacDeviceScanInterval * NSEC_PER_SEC, 10 * NSEC_PER_MSEC);
    @miws_weak(self);
    dispatch_source_set_event_handler(self.deviceScanTimer, ^{
        @miws_strong(self);
        [self scanAllDevicesAndTryConnect];
    });
    dispatch_resume(self.deviceScanTimer);
    
    MIWSHighlightLog(@"start ping timmer");
    self.pingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.actionQueue);
    dispatch_source_set_timer(self.pingTimer, DISPATCH_TIME_NOW, kMIWireSessionMacPingInterval * NSEC_PER_SEC, 10 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(self.pingTimer, ^{
        @miws_strong(self);
        [self ping];
    });
    dispatch_resume(self.pingTimer);
}

- (void)stop {
    MIWSHighlightLog(@"SDK stop");
    MIWSHighlightLog(@"stop timers");
    dispatch_source_cancel(self.deviceScanTimer);
    self.deviceScanTimer = nil;
    dispatch_source_cancel(self.pingTimer);
    self.pingTimer = nil;
    
    MIWSHighlightLog(@"disconnect all devices");
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self.devices enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSMInnerDevice * _Nonnull item, BOOL * _Nonnull stop) {
            [self disconnect:item drop:NO];
        }];
    });
}

- (NSArray <NSString *> *)attachedDevices {
    __block NSMutableArray *result = nil;
    @miws_weak(self);
    dispatch_barrier_sync(self.actionQueue, ^{
        @miws_strong(self);
        [self.devices enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSMInnerDevice * _Nonnull item, BOOL * _Nonnull stop) {
            if (!result) {
                result = [[NSMutableArray alloc] init];
            }
            [result addObject:UDID];
        }];
    });
    return result;
}

- (NSArray <NSString *> *)connectedDevices {
    __block NSMutableArray *result = nil;
    @miws_weak(self);
    dispatch_barrier_sync(self.actionQueue, ^{
        @miws_strong(self);
        [self.devices enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSMInnerDevice * _Nonnull item, BOOL * _Nonnull stop) {
            if (item.connected) {
                if (!result) {
                    result = [[NSMutableArray alloc] init];
                }
                [result addObject:UDID];
            }
        }];
    });
    return result;
}

- (MIWSDeviceInfo *)deviceInfo:(NSString *)UDID {
    if (!UDID || UDID.length == 0) {
        return nil;
    }
    __block MIWSDeviceInfo *result = nil;
    @miws_weak(self);
    dispatch_barrier_sync(self.actionQueue, ^{
        @miws_strong(self);
        [self.devices enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSMInnerDevice * _Nonnull item, BOOL * _Nonnull stop) {
            if ([item.UDID isEqual:UDID]) {
                result = [[MIWSDeviceInfo alloc] initWithInnerDevice:item];
                *stop = YES;
            }
        }];
    });
    return result;
}

- (void)setObserver:(NSString *)cmd observer:(id <MIWireSessionMacObserverProtocol>)observer {
    if (!cmd || cmd.length == 0) {
        return;
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self.observers setObject:observer forKey:cmd];
    });
}

- (void)setLogReceiver:(id <MIWSLoggerReceiverProtocol>)receiver {
    [MIWSLogger setReceiver:receiver];
}

- (void)response:(NSData *)data for:(NSString *)UDID reqID:(NSString *)reqID completion:(void(^)(NSError *error))completion {
    void(^onFinished)(NSError *errorTmp) = ^(NSError *errorTmp) {
        MIWSHighlightLog(@"response to UDID(%@) reqID(%@) %@, desc: %@, reason: %@", UDID, reqID, errorTmp?@"Failed":@"Success", errorTmp?[errorTmp localizedDescription]:@"NULL", errorTmp?[errorTmp localizedFailureReason]:@"NULL");
        if (completion) {
            dispatch_async(self.outputQueue, ^{
                completion(errorTmp);
            });
        }
    };
    if (!reqID || reqID.length == 0) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10061 description:@"Response failed, reqID is NULL" causes:nil]);
        return;
    }
    if (!UDID || UDID.length == 0) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10062 description:@"Response failed, UDID is NULL" causes:nil]);
        return;
    }
    NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
    [msgDic setObject:kMIWSMessageTypeRes forKey:kMIWSMessageKeyType];
    [msgDic setObject:UDID forKey:kMIWSMessageKeyUDID];
    [msgDic setObject:reqID forKey:kMIWSMessageKeyReqID];
    if (data) {
        [msgDic setObject:data forKey:kMIWSMessageKeyData];
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        if (![self.unResponsedReqIDs objectForKey:reqID]) {
            onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10064 description:@"Response failed, reqID is no need response" causes:nil]);
            return;
        }
        [self.unResponsedReqIDs removeObjectForKey:reqID];
        [self sendMsgDic:msgDic to:UDID completion:^(NSError *error) {
            onFinished(error ? [NSError miws_errorWith:@"MIWireSessionMac" code:10063 description:[NSString stringWithFormat:@"Response failed(UDID=%@, reqID=%@), send msg dic failed", UDID, reqID] causes:error, nil] : nil);
        }];
    });
}

- (void)push:(NSData *)data to:(NSString *)UDID completion:(void(^)(NSError *error))completion {
    void(^onFinished)(NSError *errorTmp) = ^(NSError *errorTmp) {
        MIWSHighlightLog(@"push to UDID(%@) %@, desc: %@, reason: %@", UDID, errorTmp?@"Failed":@"Success", errorTmp?[errorTmp localizedDescription]:@"NULL", errorTmp?[errorTmp localizedFailureReason]:@"NULL");
        if (completion) {
            dispatch_async(self.outputQueue, ^{
                completion(errorTmp);
            });
        }
    };
    if (!UDID || UDID.length == 0) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10070 description:@"Push failed, UDID is NULL" causes:nil]);
        return;
    }
    if (!data || data.length == 0) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10072 description:@"Push failed, data is NULL" causes:nil]);
        return;
    }
    NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
    [msgDic setObject:kMIWSMessageTypePush forKey:kMIWSMessageKeyType];
    [msgDic setObject:UDID forKey:kMIWSMessageKeyUDID];
    if (data) {
        [msgDic setObject:data forKey:kMIWSMessageKeyData];
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self sendMsgDic:msgDic to:UDID completion:^(NSError *error) {
            onFinished(error ? [NSError miws_errorWith:@"MIWireSessionMac" code:10071 description:[NSString stringWithFormat:@"Push to %@ failed, send msg dic failed", UDID] causes:error, nil] : nil);
        }];
    });
}

- (void)broadcast:(NSData *)data completion:(void(^)(BOOL successed, NSError *brief, NSDictionary <NSString *, NSError *> *detail))completion {
    void(^onFinished)(BOOL successed, NSError *brief, NSDictionary <NSString *, NSError *> *detail) = ^(BOOL successed, NSError *brief, NSDictionary <NSString *, NSError *> *detail) {
        MIWSHighlightLog(@"broadcast %@, brief desc: %@", successed?@"Success":@"Failed", brief?[brief localizedDescription]:@"NULL");
        if (completion) {
            dispatch_async(self.outputQueue, ^{
                completion(successed, brief, detail);
            });
        }
    };
    if (!data || data.length == 0) {
        onFinished(NO, [NSError miws_errorWith:@"MIWireSessionMac" code:10080 description:@"Broadcast failed, data is NULL" causes:nil], nil);
        return;
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        NSError *errorBrief = nil;
        __block NSMutableDictionary *errorDetail = nil;
        __block BOOL hasConnectedDevice = NO;
        if (self.devices.count > 0) {
            [self.devices enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSMInnerDevice * _Nonnull item, BOOL * _Nonnull stop) {
                if (item.connected) {
                    hasConnectedDevice = YES;
                    NSMutableDictionary *msgDic = [[NSMutableDictionary alloc] init];
                    [msgDic setObject:kMIWSMessageTypePush forKey:kMIWSMessageKeyType];
                    [msgDic setObject:item.UDID forKey:kMIWSMessageKeyUDID];
                    if (data) {
                        [msgDic setObject:data forKey:kMIWSMessageKeyData];
                    }
                    [self sendMsgDic:msgDic to:item.UDID completion:^(NSError *error) {
                        if (error) {
                            if (!errorDetail) {
                                errorDetail = [[NSMutableDictionary alloc] init];
                            }
                            [errorDetail setObject:item.UDID forKey:[NSError miws_errorWith:@"MIWireSessionMac" code:10081 description:[NSString stringWithFormat:@"Broadcast to %@ failed, send msg dic failed", item.UDID] causes:error, nil]];
                        }
                    }];
                }
            }];
            if (!hasConnectedDevice) {
                errorBrief = [NSError miws_errorWith:@"MIWireSessionMac" code:10083 description:@"Broadcast failed, no device connected" causes:nil];
            } else if (errorDetail) {
                errorBrief = [NSError miws_errorWith:@"MIWireSessionMac" code:10082 description:@"Broadcast failed, send msg dic to some device failed" causes:nil];
            }
        }
        onFinished(errorBrief == nil, errorBrief, errorDetail);
    });
}

#pragma mark - selector methods
- (void)onDeviceDidAttach:(NSNotification *)notification {
    MIWSMInnerDevice *device = [[MIWSMInnerDevice alloc] initWithAttachNotification:notification];
    NSString *UDID = device.UDID;
    MIWSHighlightLog(@"Device attached, deviceID=%ld, UDID=%@", device.ID, device.UDID);
    @miws_weak(self);
    dispatch_async(self.outputQueue, ^{
        @miws_strong(self);
        [[NSNotificationCenter defaultCenter] postNotificationName:kMIWSMacNotificationDeviceAttached object:self userInfo:@{@"UDID": UDID}];
    });
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self.devices setObject:device forKey:device.UDID];
        [self connect:device];
    });
}

- (void)onDeviceDidDetach:(NSNotification *)notification {
    NSInteger deviceID = [MIWSMInnerDevice extractID:notification];
    NSString *UDID = [self UDIDForDeviceID:deviceID];
    MIWSHighlightLog(@"Device detached, deviceID=%ld, UDID=%@", deviceID, UDID);
    if (!UDID) {
        return;
    }
    @miws_weak(self);
    dispatch_async(self.outputQueue, ^{
        @miws_strong(self);
        [[NSNotificationCenter defaultCenter] postNotificationName:kMIWSMacNotificationDeviceDetached object:self userInfo:@{@"UDID": UDID}];
    });
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self disconnectByUDID:UDID drop:YES];
    });
}

#pragma mark - PTChannelDelegate
- (void)ioFrameChannel:(MIWSPTChannel *)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(MIWSPTData *)payload {
    MIWSLowProfileLog(@"Receive msg of type %d", type);
    NSDictionary *msgDic = [NSDictionary dictionaryWithContentsOfDispatchData:payload.dispatchData];
    NSString *UDID = [msgDic objectForKey:kMIWSMessageKeyUDID];
    if (type == MIWSMessageTypeSHF) {
        [self onShakeHandFirstMsgReceived:channel msgDic:msgDic tag:tag];
    } else if (type == MIWSMessageTypeSHT) {
        [self onShakeHandThirdMsgReceived:msgDic UDID:UDID];
    } else if (type == MIWSMessageTypeData) {
        [self onDataReceived:UDID msgDic:msgDic];
    } else if (type == MIWSMessageTypePong) {
        [self onPongReceived:UDID];
    }
}

- (BOOL)ioFrameChannel:(MIWSPTChannel *)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    NSString *UDID = [self UDIDForChannel:channel];
    if (UDID) {
        return YES;
    } else {
        MIWSLog(@"Can't accept frame of type %d, size=%d, because can't find UDID for this channel", type, payloadSize);
        return NO;
    }
}

- (void)ioFrameChannel:(MIWSPTChannel *)channel didEndWithError:(NSError *)error {
    NSString *UDID = [self UDIDForChannel:channel];
    MIWSLowProfileLog(@"Channel of %@ did end with error: %@, reason: %@", UDID, [error localizedDescription], [error localizedFailureReason]);
    if (!UDID) {
        return;
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        [self disconnectByUDID:UDID drop:NO];
    });
}

#pragma mark - private methods
#pragma mark - device methods
- (NSString *)UDIDForDeviceID:(NSInteger)deviceID {
    __block NSString *result = nil;
    @miws_weak(self);
    dispatch_barrier_sync(self.actionQueue, ^{
        @miws_strong(self);
        [self.devices enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSMInnerDevice * _Nonnull item, BOOL * _Nonnull stop) {
            if (item.ID == deviceID) {
                result = UDID;
                *stop = YES;
            }
        }];
    });
    return result;
}

- (NSString *)UDIDForChannel:(MIWSPTChannel *)channel {
    __block NSString *result = nil;
    @miws_weak(self);
    dispatch_barrier_sync(self.actionQueue, ^{
        @miws_strong(self);
        [self.channels enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSPTChannel * _Nonnull item, BOOL * _Nonnull stop) {
            if (item == channel) {
                result = UDID;
                *stop = YES;
            }
        }];
    });
    return result;
}

#pragma mark connection methods
- (void)scanAllDevicesAndTryConnect {
    MIWSLowProfileLog(@"Scan all attached devices and try connect start");
    [self.devices enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSMInnerDevice * _Nonnull item, BOOL * _Nonnull stop) {
        if (item.connecting) {
            if (item.missedDeviceScan >= kMIWireSessionMacMissedDeviceScanLimit) {
                MIWSLowProfileLog(@"%@ is connecting and over time, disconnect", UDID);
                [self disconnect:item drop:NO];
            } else {
                item.missedDeviceScan++;
                MIWSLowProfileLog(@"%@ is connecting and good, do nothing", UDID);
            }
        } else if (!item.connected) {
            MIWSLowProfileLog(@"%@ is not connected, try connect", UDID);
            [self connect:item];
        } else {
            MIWSLowProfileLog(@"%@ is good, do nothing", UDID);
        }
    }];
}

- (void)connect:(MIWSMInnerDevice *)device {
    MIWSLowProfileLog(@"Try connect, deviceID=%ld, UDID=%@", device.ID, device.UDID);
    device.connecting = YES;
    device.missedDeviceScan = 0;
    MIWSPTChannel *channel = [MIWSPTChannel channelWithDelegate:self];
    channel.userInfo = device.UDID;
    @miws_weak(self);
    [channel connectToPort:self.port overUSBHub:MIWSPTUSBHub.sharedHub deviceID:@(device.ID) callback:^(NSError *error) {
        @miws_strong(self);
        @miws_weak(self);
        dispatch_async(self.actionQueue, ^{
            @miws_strong(self);
            if (error) {
                MIWSLowProfileLog(@"Connect to port for connect deviceID=%ld UDID=%@ failed, %@", device.ID, device.UDID, [error localizedDescription]);
                device.connecting = NO;
                [channel close];
            } else {
                MIWSLowProfileLog(@"Connect to port for connect deviceID=%ld UDID=%@ success", device.ID, device.UDID);
                [self.channels setObject:channel forKey:device.UDID];
            }
        });
    }];
}

- (void)disconnectByUDID:(NSString *)UDID drop:(BOOL)drop {
    if (!UDID || UDID.length == 0) {
        return;
    }
    MIWSMInnerDevice *device = [self.devices objectForKey:UDID];
    [self disconnect:device drop:drop];
}

- (void)disconnect:(MIWSMInnerDevice *)device drop:(BOOL)drop {
    if (!device) {
        return;
    }
    BOOL needCallDelegate = YES;
    MIWSPTChannel *channel = [self.channels objectForKey:device.UDID];
    if (channel) {
        [channel close];
        [self.channels removeObjectForKey:device.UDID];
    } else {
        needCallDelegate = NO;
    }
    if (!device.connected) {
        needCallDelegate = NO;
    }
    device.missedDeviceScan = 0;
    device.connected = NO;
    device.connecting = NO;
    if (drop) {
        [self.devices removeObjectForKey:device.UDID];
    }
    if (needCallDelegate) {
        MIWSHighlightLog(@"Device disconnected, deviceID=%ld, UDID=%@", device.ID, device.UDID);
        @miws_weak(self);
        dispatch_async(self.outputQueue, ^{
            @miws_strong(self);
            [[NSNotificationCenter defaultCenter] postNotificationName:kMIWSMacNotificationDeviceDisconnected object:self userInfo:@{@"UDID": device.UDID}];
        });
    }
}

#pragma mark send message
- (void)sendMsgDic:(NSDictionary *)msgDic to:(NSString *)UDID completion:(void(^)(NSError *error))completion {
    void(^onFinished)(NSError *errorTmp) = ^(NSError *errorTmp) {
        MIWSLog(@"Send msg dic to %@ %@, desc: %@, reason: %@", UDID, errorTmp?@"Failed":@"Success", errorTmp?[errorTmp localizedDescription]:@"NULL", errorTmp?[errorTmp localizedFailureReason]:@"NULL");
        if (completion) {
            dispatch_async(self.outputQueue, ^{
                completion(errorTmp);
            });
        }
    };
    if (!msgDic) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10080 description:@"Send msg dic failed, msgDic is NULL" causes:nil]);
        return;
    }
    if (!UDID || UDID.length == 0) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10081 description:@"Send msg dic failed, UDID is NULL" causes:nil]);
        return;
    }
    dispatch_data_t payload = [msgDic createReferencingDispatchData];
    MIWSMInnerDevice *device = [self.devices objectForKey:UDID];
    if (!device) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10082 description:[NSString stringWithFormat:@"Send msg dic to %@ failed, can't find device record", UDID] causes:nil]);
        return;
    }
    if (!device.connected) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10083 description:[NSString stringWithFormat:@"Send msg dic to %@ failed, device not connected", UDID] causes:nil]);
        return;
    }
    MIWSPTChannel *channel = [self.channels objectForKey:UDID];
    if (!channel) {
        onFinished([NSError miws_errorWith:@"MIWireSessionMac" code:10084 description:[NSString stringWithFormat:@"Send msg dic to %@ failed, can't find channel", UDID] causes:nil]);
        return;
    }
    [channel sendFrameOfType:MIWSMessageTypeData tag:MIWSPTFrameNoTag withPayload:payload callback:^(NSError *error) {
        onFinished(error ? [NSError miws_errorWith:@"MIWireSessionMac" code:10085 description:[NSString stringWithFormat:@"Send msg dic to %@ failed, send frame failed", UDID] causes:error, nil] : nil);
    }];
}

#pragma mark on messages received
- (void)onShakeHandFirstMsgReceived:(MIWSPTChannel *)channel msgDic:(NSDictionary *)msgDic tag:(uint32_t)tag {
    NSString *UDID = [self UDIDForChannel:channel];
    MIWSLog(@"Received first shake hand msg from %@", UDID);
    if (!UDID) {
        return;
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        MIWSMInnerDevice *device = [self.devices objectForKey:UDID];
        if (!device) {
            MIWSLog(@"Received first shake hand msg from %@, can't find device record", UDID);
            return;
        }
        device.connected = YES;
        NSMutableDictionary *newMsgDic = [NSMutableDictionary dictionaryWithDictionary:msgDic];
        [newMsgDic setObject:UDID forKey:kMIWSMessageKeyUDID];
        dispatch_data_t payload = [newMsgDic createReferencingDispatchData];
        [channel sendFrameOfType:MIWSMessageTypeSHS tag:tag withPayload:payload callback:^(NSError *error) {
            MIWSLog(@"Send third shake hand msg to %@ %@, desc: %@, reason: %@", UDID, error?@"Failed":@"Success", error?[error localizedDescription]:@"NULL", error?[error localizedFailureReason]:@"NULL");
        }];
    });
}

- (void)onShakeHandThirdMsgReceived:(NSDictionary *)msgDic UDID:(NSString *)UDID {
    MIWSLog(@"Received third shake hand msg from %@", UDID);
    if (!UDID) {
        return;
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        MIWSMInnerDevice *device = [self.devices objectForKey:UDID];
        if (!device) {
            MIWSLog(@"Received third shake hand msg from %@, can't find device record", UDID);
            return;
        }
        NSDictionary *deviceInfo = [msgDic objectForKey:kMIWSMessageKeyDeviceInfo];
        device.name = [deviceInfo objectForKey:kMIWSMessageKeyDIName];
        device.sysVersion = [deviceInfo objectForKey:kMIWSMessageKeyDISysVersion];
        device.screenSize = [deviceInfo objectForKey:kMIWSMessageKeyDIScreenSize];
        device.screenScale = [deviceInfo objectForKey:kMIWSMessageKeyDIScreenScale];
        device.connecting = NO;
        MIWSHighlightLog(@"Device connected, deviceID=%ld, UDID=%@", device.ID, device.UDID);
        @miws_weak(self);
        dispatch_async(self.outputQueue, ^{
            @miws_strong(self);
            [[NSNotificationCenter defaultCenter] postNotificationName:kMIWSMacNotificationDeviceConnected object:self userInfo:@{@"UDID": UDID}];
        });
    });
}

#pragma mark ping pong methods
- (void)ping {
    MIWSLowProfileLog(@"Ping start");
    [self.devices enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull UDID, MIWSMInnerDevice * _Nonnull item, BOOL * _Nonnull stop) {
        if (item.connected) {
            MIWSPTChannel *channel = [self.channels objectForKey:UDID];
            if (channel) {
                if (item.missedPing > kMIWireSessionMacMissedPingLimit) {
                    MIWSLowProfileLog(@"Missed ping count for %@ is over limit, disconnect", UDID);
                    item.missedPing = 0;
                    [self disconnect:item drop:NO];
                } else {
                    MIWSLowProfileLog(@"Send ping msg to %@", UDID);
                    NSDictionary *msgDic = @{kMIWSMessageKeyUDID: UDID};
                    dispatch_data_t payload = [msgDic createReferencingDispatchData];
                    [channel sendFrameOfType:MIWSMessageTypePing tag:MIWSPTFrameNoTag withPayload:payload callback:^(NSError *error) {
                        MIWSLowProfileLog(@"Send ping msg to %@ %@, desc: %@, reason: %@", UDID, error?@"Failed":@"Success", error?[error localizedDescription]:@"NULL", error?[error localizedFailureReason]:@"NULL");
                    }];
                    item.missedPing = item.missedPing + 1;
                }
            } else {
                MIWSLowProfileLog(@"Can't find channel record for %@, disconnect", UDID);
                [self disconnect:item drop:NO];
            }
        } else {
            MIWSLowProfileLog(@"%@ is not connected, do nothing", UDID);
        }
    }];
}

- (void)onPongReceived:(NSString *)UDID {
    MIWSLowProfileLog(@"Received pong msg from %@", UDID);
    if (!UDID) {
        return;
    }
    @miws_weak(self);
    dispatch_async(self.actionQueue, ^{
        @miws_strong(self);
        MIWSMInnerDevice *device = [self.devices objectForKey:UDID];
        if (device) {
            device.missedPing = 0;
        } else {
            MIWSLowProfileLog(@"Can't find device record for pong msg of %@", UDID);
        }
    });
}

#pragma mark on data received
- (void)onDataReceived:(NSString *)UDID msgDic:(NSDictionary *)msgDic {
    NSString *type = [msgDic objectForKey:kMIWSMessageKeyType];
    NSString *cmd = [msgDic objectForKey:kMIWSMessageKeyCmd];
    MIWSLog(@"Received data msg from %@, type=%@, cmd=%@", UDID, type, cmd);
    if (!UDID || UDID.length == 0) {
        return;
    }
    if (![type isEqualToString:kMIWSMessageTypeReq]) {
        return;
    }
    if (!cmd || cmd.length == 0) {
        return;
    }
    NSString *reqID = [msgDic objectForKey:kMIWSMessageKeyReqID];
    NSData *data = [msgDic objectForKey:kMIWSMessageKeyData];
    id<MIWireSessionMacObserverProtocol> observer = [self.observers objectForKey:cmd];
    if (!observer) {
        MIWSLog(@"Received data msg from %@, type=%@, cmd=%@, can't find observer", UDID, type, cmd);
        return;
    }
    if ([observer respondsToSelector:@selector(wireSession:onRequest:reqID:cmd:data:)]) {
        [self.unResponsedReqIDs setObject:reqID forKey:reqID];
        @miws_weak(self);
        dispatch_async(self.outputQueue, ^{
            @miws_strong(self);
            [observer wireSession:self onRequest:UDID reqID:reqID cmd:cmd data:data];
        });
    } else {
        MIWSLog(@"Received data msg from %@, type=%@, cmd=%@, can't find selector in observer", UDID, type, cmd);
    }
}

@end
