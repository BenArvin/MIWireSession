//
//  MIWSUtils.m
//  MIWireSessioniOS
//
//  Created by BenArvin on 2020/11/30.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import "MIWSUtils.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation MIWSUtils

+ (NSString *)md5Str:(NSString *)str {
    return [self md5Data:[str dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (NSString *)md5Data:(NSData *)data {
    if (!data || data.length == 0) {
        return nil;
    }
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    CC_MD5_Update(&md5, data.bytes, (CC_LONG)data.length);
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(result, &md5);
    NSMutableString *resultString = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [resultString appendFormat:@"%02X", result[i]];
    }
    return resultString;
}

+ (NSString *)UUID {
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    NSString *UUID = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return UUID;
}

@end
