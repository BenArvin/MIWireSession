//
//  MIWireSessionMac.h
//  Pods
//
//  Created by BenArvin on 2020/11/17.
//

#import <Foundation/Foundation.h>
#import "MIWSLogger.h"

@class MIWireSessionMac;

extern NSString *const kMIWSMacNotificationDeviceAttached;
extern NSString *const kMIWSMacNotificationDeviceDetached;
extern NSString *const kMIWSMacNotificationDeviceConnected;
extern NSString *const kMIWSMacNotificationDeviceDisconnected;

@protocol MIWireSessionMacObserverProtocol <NSObject>

@optional
- (void)wireSession:(MIWireSessionMac *)session onRequest:(NSString *)UDID reqID:(NSString *)reqID cmd:(NSString *)cmd data:(NSData *)data;

@end

@interface MIWSDeviceInfo: NSObject

@property (nonatomic) NSString *UDID;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *sysVersion;
@property (nonatomic) NSString *screenSize;
@property (nonatomic) NSString *screenScale;

@end

@interface MIWireSessionMac : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPort:(in_port_t)port;

- (void)setObserver:(NSString *)cmd observer:(id <MIWireSessionMacObserverProtocol>)observer;
- (void)setLogReceiver:(id <MIWSLoggerReceiverProtocol>)receiver;

- (void)start;
- (void)stop;

- (NSArray <NSString *> *)attachedDevices;
- (NSArray <NSString *> *)connectedDevices;
- (MIWSDeviceInfo *)deviceInfo:(NSString *)UDID;

- (void)response:(NSData *)data for:(NSString *)UDID reqID:(NSString *)reqID completion:(void(^)(NSError *error))completion;
- (void)push:(NSData *)data to:(NSString *)UDID completion:(void(^)(NSError *error))completion;
- (void)broadcast:(NSData *)data completion:(void(^)(BOOL successed, NSError *brief, NSDictionary <NSString *, NSError *> *detail))completion;

@end
