//
//  GOTwitterUser.h
//  EasyFollow
//
//  Created by Samuel Goodwin on 6/12/11.
//  Copyright 2011 Goodwinlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^GOCompletionBlock)(void);

@class ACAccount;
@interface GOTwitterUser : NSObject
@property(nonatomic, copy) NSString *username;
@property(nonatomic, copy) NSString *realName;
@property(nonatomic, copy) NSString *tagline;
@property(nonatomic, retain) UIImage *image;
@property(nonatomic, retain) NSURL *profileImageURL;
@property(nonatomic, assign, getter=isFollowing) BOOL following;

+ (id)userWithDictionary:(NSDictionary*)dict;
- (void)updateWithDictionary:(NSDictionary*)dict;

- (void)followFromAccount:(ACAccount*)account andBlock:(GOCompletionBlock)block;
- (void)unfollowFromAccount:(ACAccount*)account andBlock:(GOCompletionBlock)block;

@end
