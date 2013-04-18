//
//  GOViewController.m
//  EasyFollow
//
//  Created by Samuel Goodwin on 4/9/12.
//  Copyright (c) 2012 SNAP Interactive. All rights reserved.
//

#import "GOSearchViewController.h"
#import "GOAccountsViewController.h"
#import "GOTwitterUser.h"
#import <Social/Social.h>
#import "GOUserCell.h"
#import "JGAFImageCache.h"
#import "MBProgressHUD.h"

@interface GOSearchViewController ()
@property (nonatomic, strong) SLRequest *searchRequest;
@property (nonatomic, strong) NSMutableSet *blockedIDs;
@property (nonatomic, strong) NSMutableSet *followingIDs;
- (void)becomeReady;
- (void)accountsDidChange:(NSNotification *)notification;
@end

@implementation GOSearchViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.accountsController setup];
    
    [self getBlocksAndFollows];
    
    self.searchBar.placeholder = NSLocalizedString(@"real name or username", @"Search bar placeholder");
}

- (void)viewDidLoad{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountsDidChange:) name:GOAccountsDidChangeNotification object:nil];
    
    ACAccountStore *store = [[ACAccountStore alloc] init];
    ACAccountType *type = [store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [store requestAccessToAccountsWithType:type options:nil completion:^(BOOL granted, NSError *error) {
        NSArray *accounts = [store accountsWithAccountType:type];
        dispatch_async(dispatch_get_main_queue(), ^{
            if(!granted || accounts == nil || [accounts count] == 0){
                NSString *title = NSLocalizedString(@"Sorry", @"Alert title for when we don't have twitter access.");
                NSString *message = NSLocalizedString(@"We cannot do anything without access to one of your twitter accounts.", @"Alert message when we don't have twitter access.");
                                                      
                [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"Ok", @"Alert button title.") otherButtonTitles:nil] show];
                
                [self.accountsController setupEmpty];
                [self.accountsController updateAccountIndicator];
            }else{
                [self becomeReady];
            }
        });
    }];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark -
#pragma mark Actions

- (void)becomeReady{
    [self.accountsController setup];
    [self.accountsController updateAccountIndicator];
    [self.searchBar setUserInteractionEnabled:YES];
    [self.searchBar becomeFirstResponder];
    
    [self getBlocksAndFollows];
}

- (void)configureCell:(UITableViewCell *)cell forTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)path{
    GOTwitterUser *user = [self.dataSource objectAtIndexPath:path];
    if(!user){
        [(GOUserCell*)cell updateForUser:nil following:self.followingIDs blocked:self.blockedIDs];
        return;
    }
    
    if(!user.image){
        [[JGAFImageCache sharedInstance] imageForURLString:[user profileImageURLString] completion:^(UIImage *image) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                // Begin a new image that will be the new image with the rounded corners
                // (here with the size of an UIImageView)
                UIGraphicsBeginImageContextWithOptions(image.size, NO, 1.0f);
                
                // Add a clip before drawing anything, in the shape of an rounded rect
                CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
                [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:image.size.width/2.0f] addClip];
                // Draw your image
                [image drawInRect:rect];
                
                // Get the image, here setting the UIImageView image
                UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
                
                // Lets forget about that we were drawing
                UIGraphicsEndImageContext();
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    user.image = newImage;
                    GOUserCell *currentCell = (GOUserCell*)[tableView cellForRowAtIndexPath:path];
                    [currentCell setProfileImage:newImage];
                });
            });
        }];
    }
    [(GOUserCell*)cell updateForUser:user following:self.followingIDs blocked:self.blockedIDs];
}

- (void)accountsDidChange:(NSNotification *)notification{
    [self search:self.searchBar.text];
}

#pragma mark -
#pragma mark Searching

- (void)search:(NSString*)term{
    if(!term || [term length] == 0){
        return;
    }
    
    [MBProgressHUD showHUDAddedTo:[self.view superview] animated:YES];
    
    [self.dataSource setResults:nil];
    [self.searchDisplayController.searchResultsTableView reloadData];
    
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/users/search.json"];
    NSDictionary *params = @{@"q":term, @"include_entities": @"0"};
    
    self.searchRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
    ACAccount *currentAccount = [self.accountsController currentAccount];
    NSString *username = [@"@" stringByAppendingString:[currentAccount username]];
    [self.searchRequest setAccount:currentAccount];
    
    [self.searchRequest performRequestWithHandler:^(NSData *__strong responseData, NSHTTPURLResponse *__strong urlResponse, NSError *__strong error) {
        if([urlResponse statusCode] != 200){
            NSLog(@"error %i, %@", [urlResponse statusCode], [error localizedDescription]);
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                [MBProgressHUD hideHUDForView:[self.view superview] animated:YES];
            });
            return;
        }
        
        NSArray *returnedObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
        NSMutableArray *newResults = [NSMutableArray array];
        [returnedObject enumerateObjectsUsingBlock:^(__strong id obj, NSUInteger idx, BOOL *stop) {
            GOTwitterUser *user = [GOTwitterUser userWithDictionary:obj];
            if(![[user username] isEqualToString:username]){
                [newResults addObject:user];
            }
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.dataSource setResults:newResults];
            [self.searchDisplayController.searchResultsTableView reloadData];
            
            [MBProgressHUD hideHUDForView:[self.view superview] animated:YES];
        });
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)aSearchBar{
    [aSearchBar resignFirstResponder];
    if([[aSearchBar text] length] > 0){
        [self search:[aSearchBar text]];
    }
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *username = [[self.accountsController currentAccount] username];
    
    GOTwitterUser *user = [self.dataSource objectAtIndexPath:indexPath];
    if(!user){
        return;
    }
    
    NSString *followTitle = nil;
    if([self isFollowing:user]){
        followTitle = NSLocalizedString(@"Unfollow", @"Stop following action sheet button.");
    }else{
        followTitle = NSLocalizedString(@"Follow", @"Start following action sheet button.");
    }
    
    NSString *blockedTitle = nil;
    if([self isBlocked:user]){
        blockedTitle = NSLocalizedString(@"Unblock", @"Unblock action sheet button");
    }else{
        blockedTitle = NSLocalizedString(@"Block", @"Block action sheet button");
    }
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:username delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:blockedTitle otherButtonTitles:followTitle, nil];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    UITableView *tableView = self.searchDisplayController.searchResultsTableView;
    NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if(buttonIndex == [actionSheet cancelButtonIndex]){
        return;
    }
    
    GOTwitterUser *user = [self.dataSource objectAtIndexPath:indexPath];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicatorView setFrame:CGRectMake(0.0f, 0.0f, 30.0f, 30.0f)];
    [indicatorView startAnimating];
    cell.accessoryView = indicatorView;
    
    GOCompletionBlock block = ^(void){
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    };
    
    if(buttonIndex == [actionSheet destructiveButtonIndex]){
        if([self isBlocked:user]){
            [self.blockedIDs removeObject:[user userID]];
            [user unblockFromAccount:[self.accountsController currentAccount] completion:block];
        }else{
            [self.blockedIDs addObject:[user userID]];
            [user blockFromAccount:[self.accountsController currentAccount] completion:block];
        }
        return;
    }
    
    if([self isFollowing:user]){
        [self.followingIDs removeObject:[user userID]];
        [user unfollowFromAccount:[self.accountsController currentAccount] completion:block];
    }else{
        [self.followingIDs addObject:[user userID]];
        [user followFromAccount:[self.accountsController currentAccount] completion:block];
    }
}

#pragma mark -
#pragma mark UISearchDisplayDelegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString{
    [self.dataSource setResults:nil];
    [self.searchDisplayController.searchResultsTableView reloadData];
    return NO;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 65.0f;
}

#pragma mark - Blocks and Follows

- (void)getBlocksAndFollows
{
    NSURL *blockURL = [NSURL URLWithString:@"https://api.twitter.com/1.1/blocks/ids.json"];
    SLRequest *blockRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:blockURL parameters:@{@"stringify_ids":@"1"}];
    ACAccount *currentAccount = [self.accountsController currentAccount];
    [blockRequest setAccount:currentAccount];
    
    [blockRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        NSDictionary *returnedObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
        NSArray *blockedIDs = returnedObject[@"ids"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.blockedIDs = [NSMutableSet setWithArray:blockedIDs];
            [self.searchDisplayController.searchResultsTableView reloadData];
        });
    }];
    
    NSURL *friendURL = [NSURL URLWithString:@"https://api.twitter.com/1.1/friends/ids.json"];
    SLRequest *friendRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:friendURL parameters:@{@"stringify_ids":@"1"}];
    [friendRequest setAccount:currentAccount];
    
    [friendRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        NSDictionary *returnedObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
        NSArray *friendIDs = returnedObject[@"ids"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.followingIDs = [NSMutableSet setWithArray:friendIDs];
            [self.searchDisplayController.searchResultsTableView reloadData];
        });
    }];
}

- (BOOL)isBlocked:(GOTwitterUser *)user
{
    return [self.blockedIDs containsObject:[user userID]];
}

- (BOOL)isFollowing:(GOTwitterUser *)user
{
    return [self.followingIDs containsObject:[user userID]];
}

@end
