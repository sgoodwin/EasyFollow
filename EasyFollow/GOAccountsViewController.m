//
//  GOAccountsControllerViewController.m
//  EasyFollow
//
//  Created by Samuel Goodwin on 4/9/12.
//  Copyright (c) 2012 SNAP Interactive. All rights reserved.
//

#import "GOAccountsViewController.h"
#import "NSUserDefaults+GODictionaryLiterals.h"
#import <QuartzCore/QuartzCore.h>

@interface GOAccountsViewController()
- (NSUInteger)indexOfAccount:(ACAccount*)account;
@property (nonatomic, assign, getter=isEmpty) BOOL empty;
@end

NSString *const GOAccountsDidChangeNotification = @"omgtheaccountchanged!";
NSString *const kDefaultAccountIdentifierKey = @"omgcurrentAccountIdentifier";

@implementation GOAccountsViewController

- (void)setup{
    _store = [[ACAccountStore alloc] init];
    
    ACAccountType *type = [_store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    _accounts = [_store accountsWithAccountType:type];
    
    [self.pageControl setNumberOfPages:[_accounts count]];
    [self.pageControl setCurrentPage:[self indexOfAccount:[self currentAccount]]];
    
    UILabel *label = self.accountNameLabel;
    label.textColor = [UIColor colorWithRed:0.831f green:0.831f blue:0.831f alpha: 1.0f];
    
    CALayer *layer = label.layer;
    layer.shadowColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:1.0f].CGColor;
    layer.shadowOffset = CGSizeMake(0.1f, 2.1f);
    layer.shadowRadius = 1.0f;

}

- (void)setupEmpty
{
    _accounts = @[NSLocalizedString(@"No Accounts", @"Label for no accounts remaining.")];
    self.empty = YES;
    
    [self.pageControl setNumberOfPages:1];
    [self.pageControl setCurrentPage:0];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (NSUInteger)indexOfAccount:(ACAccount*)account{
    return [_accounts indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        ACAccount *comparer = obj;
        return [[account identifier] isEqualToString:[comparer identifier]];
    }];
}

- (ACAccount*)currentAccount{
    if([self isEmpty]){
        return nil;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *identifier = defaults[kDefaultAccountIdentifierKey];
    if(identifier){
        return [_store accountWithIdentifier:identifier];
    }
    
    ACAccount *account = _accounts[0];
    
    defaults[kDefaultAccountIdentifierKey] = [account identifier];
    return account;
}

- (void)updateAccountIndicator{
    ACAccount *currentAccount = [self currentAccount];
    if([self isEmpty]){
        self.accountNameLabel.text = (NSString *)currentAccount;
    }else{
        self.accountNameLabel.text = [currentAccount username];
    }
}

- (void)animatedIndicator:(GOIndicatorDirection)direction{
    CGFloat totalWidth = CGRectGetWidth(self.view.bounds);
    CGRect originalFrame = self.accountNameLabel.frame;
    CGFloat x;
    switch(direction){
        case GOIndicatorDirectionLeft:
            x = -totalWidth;
            break;
        case GOIndicatorDirectionRight:
            x = totalWidth;
            break;
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        self.accountNameLabel.frame = CGRectMake(x, CGRectGetMinY(originalFrame), CGRectGetWidth(originalFrame), CGRectGetHeight(originalFrame));
        self.accountNameLabel.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [self updateAccountIndicator];
        self.accountNameLabel.frame = originalFrame;
        [UIView animateWithDuration:0.3 animations:^{
            self.accountNameLabel.alpha = 1.0f;
        }];
    }];
}

- (IBAction)pageChanged:(id)sender{
    NSUInteger page = [self.pageControl currentPage];
    NSUInteger index = [self indexOfAccount:[self currentAccount]];
    if(page < index){
        [self prevAccount:nil];
    }else{
        [self nextAccount:nil];
    }
}

- (IBAction)nextAccount:(id)sender{
    if([self isEmpty]){
        return;
    }
    
    ACAccount *currentAccount = [self currentAccount];
    NSUInteger index = [self indexOfAccount:currentAccount] + 1;
    if(index >= [_accounts count]){
        index = 0;
    }
    [self.pageControl setCurrentPage:index];
    
    ACAccount *newAccount = _accounts[index];
    [NSUserDefaults standardUserDefaults][kDefaultAccountIdentifierKey] = [newAccount identifier];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GOAccountsDidChangeNotification object:nil];
    [self animatedIndicator:GOIndicatorDirectionLeft];
}

- (IBAction)prevAccount:(id)sender{
    if([self isEmpty]){
        return;
    }
    
    ACAccount *currentAccount = [self currentAccount];
    NSUInteger index = [self indexOfAccount:currentAccount];
    if(index == 0){
        index = [_accounts count]-1;
    }else{
        index--;
    }
    [self.pageControl setCurrentPage:index];
    
    ACAccount *newAccount = _accounts[index];
    [NSUserDefaults standardUserDefaults][kDefaultAccountIdentifierKey] = [newAccount identifier];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GOAccountsDidChangeNotification object:nil];
    [self animatedIndicator:GOIndicatorDirectionRight];
}

@end
