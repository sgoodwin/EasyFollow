//
//  GOAccountsControllerViewController.h
//  EasyFollow
//
//  Created by Samuel Goodwin on 4/9/12.
//  Copyright (c) 2012 SNAP Interactive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Accounts/Accounts.h>

typedef enum{
    GOIndicatorDirectionLeft,
    GOIndicatorDirectionRight,
}GOIndicatorDirection;

extern NSString *const GOAccountsDidChangeNotification;

@interface GOAccountsViewController : UIViewController{
    ACAccountStore *_store;
    NSArray *_accounts;
}

@property (nonatomic, retain) IBOutlet UILabel *accountNameLabel;
@property (nonatomic, retain) IBOutlet UIPageControl *pageControl;

- (void)setup;

- (IBAction)pageChanged:(id)sender;
- (IBAction)nextAccount:(id)sender;
- (IBAction)prevAccount:(id)sender;

- (ACAccount*)currentAccount;
- (void)updateAccountIndicator;
@end
