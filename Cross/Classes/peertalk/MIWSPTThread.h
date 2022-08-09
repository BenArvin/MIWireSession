//
//  MIWSPTThread.h
//  MIWireSessionMac
//
//  Created by BenArvin on 2021/3/2.
//

#import <Foundation/Foundation.h>

@interface MIWSPTThread : NSObject

+ (MIWSPTThread *)shared;

- (dispatch_queue_t)queue;

@end
