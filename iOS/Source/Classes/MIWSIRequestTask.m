//
//  MIWSIRequestTask.m
//  MIWireSessioniOS
//
//  Created by BenArvin on 2020/12/2.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import "MIWSIRequestTask.h"
#import "MIWSUtils.h"

@interface MIWSIRequestTask() {
}

@property (atomic, readwrite) BOOL running;

@end

@implementation MIWSIRequestTask

- (instancetype)init {
    self = [super init];
    if (self) {
        _overtime = kMIWSIRequestTaskOvertime;
    }
    return self;
}

- (void)start {
    self.running = YES;
    if ([self.delegate respondsToSelector:@selector(onRequestTaskOvertime:)]) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.overtime * NSEC_PER_SEC)),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                       ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.running) {
                return;
            }
            [strongSelf stop];
            [strongSelf.delegate onRequestTaskOvertime:strongSelf];
        });
    }
}

- (void)stop {
    self.running = NO;
}

@end
