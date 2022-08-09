//
//  MIWSLogger.m
//  MIWireSessioniOS
//
//  Created by BenArvin on 2020/11/19.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import "MIWSLogger.h"
#import "MIWSUtils.h"

@interface MIWSLogger() {
}

@property (nonatomic, weak) id <MIWSLoggerReceiverProtocol> innerReceiver;
@property (nonatomic) NSDateFormatter *formatter;
@property (nonatomic) MIWSLogLevel logLevel;

+ (instancetype)shared;
- (void)log:(NSDate *)date file:(const char *)file func:(const char *)func line:(int)line priority:(MIWSLogPriority)priority text:(NSString *)text;

@end

void MIWSLogV(const char *file, const char *func, int line, MIWSLogPriority priority, NSString *format, ...) {
    NSDate *date = [NSDate date];
    va_list args;
    va_start(args, format);
    NSString *logStr = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [[MIWSLogger shared] log:date file:file func:func line:line priority:priority text:logStr];
}

@implementation MIWSLogger

- (instancetype)init {
    self = [super init];
    if (self) {
        _formatter = [[NSDateFormatter alloc] init];
        [_formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        _logLevel = MIWSLogLevelDetail;
    }
    return self;
}

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static MIWSLogger *_shared;
    dispatch_once(&onceToken, ^{
        _shared = [[MIWSLogger alloc] init];
    });
    return _shared;
}

#pragma mark - public methods
+ (void)setLevel:(MIWSLogLevel)level {
    [[self shared] setLogLevel:level];
}

+ (void)setReceiver:(id<MIWSLoggerReceiverProtocol>)receiver {
    [[self shared] setInnerReceiver:receiver];
}

#pragma mark - private methods
- (void)log:(NSDate *)date file:(const char *)file func:(const char *)func line:(int)line priority:(MIWSLogPriority)priority text:(NSString *)text {
    if (![self isLogValid:priority]) {
        return;
    }
    NSString *dateStr = [self.formatter stringFromDate:date];
    NSString *fileStr = nil;
    NSURL *fileUrl = nil;
    NSString *fileName = nil;
    if (file) {
        fileStr = [NSString stringWithUTF8String:file];
    }
    if (fileStr) {
        fileUrl = [[NSURL alloc] initFileURLWithPath:fileStr];
    }
    if (fileUrl) {
        fileName = [fileUrl lastPathComponent];
    }
    NSString *fullStr = [NSString stringWithFormat:@"[%@][%@:%d]%s:%@", dateStr, fileName, line, func, text?:@""];
#ifdef DEBUG
    NSLog(@"%@", fullStr);
#endif
    if ([self.innerReceiver respondsToSelector:@selector(onWireSessionLog:)]) {
        @miws_weak(self);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @miws_strong(self);
            [self.innerReceiver onWireSessionLog:fullStr];
        });
    }
}

- (BOOL)isLogValid:(MIWSLogPriority)priority {
    if (self.logLevel == MIWSLogLevelQuite) {
        return NO;
    } else if (self.logLevel == MIWSLogLevelVerbose) {
        return YES;
    } else {
        NSUInteger priorityNum = priority;
        NSUInteger logLevelNum = self.logLevel;
        return (priorityNum >= logLevelNum);
    }
}

@end
