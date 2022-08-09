//
//  NSError+MIWSError.h
//
//
//  Created by benarvin on 2020/7/17.
//  Copyright (c) 2020 BenArvin. All rights reserved.

#import <Foundation/Foundation.h>

@interface NSError (MIWSError)

+ (NSError * _Nonnull)miws_errorWith:(NSString * _Nonnull)domain
                               code:(NSInteger)code
                             causes:(NSError * _Nullable)item,...NS_REQUIRES_NIL_TERMINATION;

+ (NSError * _Nonnull)miws_errorWith:(NSString * _Nonnull)domain
                               code:(NSInteger)code
                        description:(NSString * _Nullable)description
                             causes:(NSError * _Nullable)item,...NS_REQUIRES_NIL_TERMINATION;

+ (NSError * _Nonnull)miws_errorWith:(NSString * _Nonnull)domain
                               code:(NSInteger)code
                        description:(NSString * _Nullable)description
                             reason:(NSString * _Nullable)reason
                             causes:(NSError * _Nullable)item,...NS_REQUIRES_NIL_TERMINATION;

+ (NSError * _Nonnull)miws_errorWith:(NSString * _Nonnull)domain
                               code:(NSInteger)code
                        description:(NSString * _Nullable)description
                             reason:(NSString * _Nullable)reason
                 recoverySuggestion:(NSString * _Nullable)recoverySuggestion
                             causes:(NSError * _Nullable)item,...NS_REQUIRES_NIL_TERMINATION;

@end
