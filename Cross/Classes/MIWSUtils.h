//
//  MIWSUtils.h
//  MIWireSessioniOS
//
//  Created by BenArvin on 2020/11/30.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import <Foundation/Foundation.h>

#define miws_weak(o) try{}@finally{} __weak typeof(o) o##Weak = o;
#define miws_strong(o) autoreleasepool{} __strong typeof(o) o = o##Weak;

@interface MIWSUtils : NSObject

+ (NSString *)md5Str:(NSString *)str;
+ (NSString *)md5Data:(NSData *)data;
+ (NSString *)UUID;

@end
