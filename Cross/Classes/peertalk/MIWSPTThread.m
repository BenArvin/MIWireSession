//
//  MIWSPTThread.m
//  MIWireSessionMac
//
//  Created by BenArvin on 2021/3/2.
//

#import "MIWSPTThread.h"

@interface MIWSPTThread() {
}

@property (nonatomic) dispatch_queue_t defaultQueue;

@end

@implementation MIWSPTThread

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaultQueue = dispatch_queue_create([NSString stringWithFormat:@"com.MIWireSessionMac.MIWSPTThread.queue.%p", self].UTF8String, DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (MIWSPTThread *)shared {
    static dispatch_once_t onceToken;
    static MIWSPTThread *_shared;
    dispatch_once(&onceToken, ^{
        _shared = [[MIWSPTThread alloc] init];
    });
    return _shared;
}

- (dispatch_queue_t)queue {
    return self.defaultQueue;
}

@end
