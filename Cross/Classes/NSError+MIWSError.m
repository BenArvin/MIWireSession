//
//  NSError+MIWSError.m
//
//
//  Created by benarvin on 2020/7/17.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import "NSError+MIWSError.h"

static NSString *const kMIWSErrorUnknown = @"Unknown";
static NSString *const kMIWSErrorDomainKey = @"Domain";
static NSString *const kMIWSErrorCodeKey = @"Code";
static NSString *const kMIWSErrorDescriptionKey = @"Description";
static NSString *const kMIWSErrorReasonKey = @"Reason";
static NSString *const kMIWSErrorSuggestionKey = @"Suggestion";
static NSString *const kMIWSErrorCausesKey = @"Causes";

@implementation NSError (MIWSError)

+ (NSError *)miws_errorWith:(NSString *)domain code:(NSInteger)code causes:(NSError *)item,...NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray *causesItems = nil;
    va_list arguments;
    NSError *eachItem;
    if (item) {
        causesItems = [[NSMutableArray alloc] init];
        [causesItems addObject:item];
        va_start(arguments, item);
        while ((eachItem = va_arg(arguments, NSError *))) {
            [causesItems addObject:eachItem];
        }
        va_end(arguments);
    }
    return [self miws_errorWith:domain code:code description:nil reason:nil recoverySuggestion:nil causesItems:causesItems];
}

+ (NSError *)miws_errorWith:(NSString *)domain code:(NSInteger)code description:(NSString *)description causes:(NSError *)item,...NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray *causesItems = nil;
    va_list arguments;
    NSError *eachItem;
    if (item) {
        causesItems = [[NSMutableArray alloc] init];
        [causesItems addObject:item];
        va_start(arguments, item);
        while ((eachItem = va_arg(arguments, NSError *))) {
            [causesItems addObject:eachItem];
        }
        va_end(arguments);
    }
    return [self miws_errorWith:domain code:code description:description reason:nil recoverySuggestion:nil causesItems:causesItems];
}

+ (NSError *)miws_errorWith:(NSString *)domain code:(NSInteger)code description:(NSString *)description reason:(NSString *)reason causes:(NSError *)item,...NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray *causesItems = nil;
    va_list arguments;
    NSError *eachItem;
    if (item) {
        causesItems = [[NSMutableArray alloc] init];
        [causesItems addObject:item];
        va_start(arguments, item);
        while ((eachItem = va_arg(arguments, NSError *))) {
            [causesItems addObject:eachItem];
        }
        va_end(arguments);
    }
    return [self miws_errorWith:domain code:code description:description reason:reason recoverySuggestion:nil causesItems:causesItems];
}

+ (NSError *)miws_errorWith:(NSString *)domain code:(NSInteger)code description:(NSString *)description reason:(NSString *)reason recoverySuggestion:(NSString *)recoverySuggestion causes:(NSError *)item,...NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray *causesItems = nil;
    va_list arguments;
    NSError *eachItem;
    if (item) {
        causesItems = [[NSMutableArray alloc] init];
        [causesItems addObject:item];
        va_start(arguments, item);
        while ((eachItem = va_arg(arguments, NSError *))) {
            [causesItems addObject:eachItem];
        }
        va_end(arguments);
    }
    return [self miws_errorWith:domain code:code description:description reason:reason recoverySuggestion:recoverySuggestion causesItems:causesItems];
}

#pragma mark - private methods
+ (NSError *)miws_errorWith:(NSString *)domain code:(NSInteger)code description:(NSString *)description reason:(NSString *)reason recoverySuggestion:(NSString *)recoverySuggestion causesItems:(NSArray <NSError *> *)causesItems {
    NSString *domainTmp = domain ? domain : kMIWSErrorUnknown;
    NSString *desTmp = [self miws_buildDes:domain code:code des:description];
    
    NSMutableDictionary *fullDic = [[NSMutableDictionary alloc] init];
    [fullDic setObject:domainTmp forKey:kMIWSErrorDomainKey];
    [fullDic setObject:@(code) forKey:kMIWSErrorCodeKey];
    if (description) {
        [fullDic setObject:description forKey:kMIWSErrorDescriptionKey];
    }
    if (reason) {
        [fullDic setObject:reason forKey:kMIWSErrorReasonKey];
    }
    if (recoverySuggestion) {
        [fullDic setObject:recoverySuggestion forKey:kMIWSErrorSuggestionKey];
    }
    
    NSMutableArray *causeDics = nil;
    for (NSError *item in causesItems) {
        if (!causeDics) {
            causeDics = [[NSMutableArray alloc] init];
        }
        [causeDics addObject:[self miws_toDic:item]];
    }
    if (causeDics) {
        [fullDic setObject:causeDics forKey:kMIWSErrorCausesKey];
    }
    NSString *fullStr = [self miws_toJsonStr:fullDic];
    return [NSError errorWithDomain:domainTmp code:code userInfo:@{
        NSLocalizedDescriptionKey: desTmp,
        NSLocalizedFailureReasonErrorKey: fullStr,
        NSLocalizedRecoverySuggestionErrorKey: fullStr
    }];
}

+ (NSString *)miws_toJsonStr:(NSDictionary *)dic {
    if (!dic) {
        return nil;
    }
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData || error) {
        return nil;
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (id)miws_toDic:(NSError *)error {
    NSString *reason = [error localizedFailureReason];
    if (!reason) {
        reason = [self miws_buildDes:error.domain code:error.code des:error.localizedDescription];
    }
    NSError *errorTmp;
    id result = [NSJSONSerialization JSONObjectWithData:[reason dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&errorTmp];
    return errorTmp ? reason : (NSDictionary *)result;
}

+ (NSString *)miws_buildDes:(NSString *)domain code:(NSInteger)code des:(NSString *)des {
    return [NSString stringWithFormat:@"[%@-%ld] %@", domain?:kMIWSErrorUnknown, (long)code, des?:kMIWSErrorUnknown];
}

@end
