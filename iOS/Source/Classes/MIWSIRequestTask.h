//
//  MIWSIRequestTask.h
//  MIWireSessioniOS
//
//  Created by BenArvin on 2020/12/2.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import <Foundation/Foundation.h>

@class MIWSIRequestTask;

static const NSInteger kMIWSIRequestTaskOvertime = 30;

@protocol MIWSIRequestTaskProtocol <NSObject>
@required
- (void)onRequestTaskOvertime:(MIWSIRequestTask *)task;

@end

@interface MIWSIRequestTask : NSObject

@property (nonatomic, weak) id<MIWSIRequestTaskProtocol> delegate;

@property (atomic, readonly) BOOL running;
@property (nonatomic) NSString *reqID;
@property (nonatomic) NSString *cmd;
@property (nonatomic) CGFloat overtime;
@property (nonatomic) void(^completion)(NSData *response, NSError *error);

- (void)start;
- (void)stop;

@end
