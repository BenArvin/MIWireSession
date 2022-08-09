//
//  MIWSLogger.h
//  MIWireSessioniOS
//
//  Created by BenArvin on 2020/11/19.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MIWSLogPriority) {
    MIWSLogPriorityLow    = 1,
    MIWSLogPriorityNormal = 2,
    MIWSLogPriorityHigh   = 3,
};

#define MIWSLog(...) MIWSLogV(__FILE__, __FUNCTION__, __LINE__, MIWSLogPriorityNormal, __VA_ARGS__)
#define MIWSLowProfileLog(...) MIWSLogV(__FILE__, __FUNCTION__, __LINE__, MIWSLogPriorityLow, __VA_ARGS__)
#define MIWSCommonLog(...) MIWSLogV(__FILE__, __FUNCTION__, __LINE__, MIWSLogPriorityNormal, __VA_ARGS__)
#define MIWSHighlightLog(...) MIWSLogV(__FILE__, __FUNCTION__, __LINE__, MIWSLogPriorityHigh, __VA_ARGS__)

void MIWSLogV(const char *file, const char *func, int line, MIWSLogPriority level, NSString *format, ...) NS_FORMAT_FUNCTION(5,6) NS_NO_TAIL_CALL;

typedef NS_ENUM(NSUInteger, MIWSLogLevel) {
    MIWSLogLevelQuite,
    MIWSLogLevelBrief   = MIWSLogPriorityLow,
    MIWSLogLevelDetail  = MIWSLogPriorityNormal,
    MIWSLogLevelVerbose = MIWSLogPriorityHigh,
};

@protocol MIWSLoggerReceiverProtocol <NSObject>
@required
- (void)onWireSessionLog:(NSString *)log;

@end

@interface MIWSLogger : NSObject

+ (void)setLevel:(MIWSLogLevel)level;
+ (void)setReceiver:(id<MIWSLoggerReceiverProtocol>)receiver;

@end
