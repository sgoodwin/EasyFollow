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
#import <Twitter/Twitter.h>
#import "GOUserCell.h"
#import "GOImageCache.h"

@interface GOSearchViewController ()
- (void)becomeReady;
- (void)accountsDidChange:(NSNotification *)notification;
@end

@implementation GOSearchViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountsDidChange:) name:GOAccountsDidChangeNotification object:nil];
    
    ACAccountStore *store = [[ACAccountStore alloc] init];
    ACAccountType *type = [store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [store requestAccessToAccountsWithType:type withCompletionHandler:^(BOOL granted, NSError *__strong error) {
        NSArray *accounts = [store accountsWithAccountType:type];
        dispatch_async(dispatch_get_main_queue(), ^{
            if(!granted || accounts == nil || [accounts count] == 0){
                [self performSegueWithIdentifier:@"toInfo" sender:self];
            }else{
                [self becomeReady];
            }
        });
    }];
}

- (void)viewDidUnload{
    [super viewDidUnload];
    self.statusLabel = nil;
    self.searchBar = nil;
    self.dataSource = nil;
    self.accountsController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark -
#pragma mark Actions

- (void)becomeReady{
    [self.accountsController updateAccountIndicator];
    self.statusLabel.text = NSLocalizedString(@"Search away!", @"Search controller is ready");
    [self.searchBar setUserInteractionEnabled:YES];
    [self.searchBar becomeFirstResponder];
}

- (void)configureCell:(UITableViewCell *)cell forTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)path{
    GOTwitterUser *user = [self.dataSource objectAtIndexPath:path];
    if(!user.image){
        [[GOImageCache sharedImageCache] getImageWithURL:[user profileImageURL] andCompletion:^(UIImage *image) {
            user.image = image;
            GOUserCell *currentCell = (GOUserCell*)[tableView cellForRowAtIndexPath:path];
            [currentCell setProfileImage:image];
        }];
    }
    [(GOUserCell*)cell updateForUser:user];
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
    [self.dataSource setResults:[NSArray array]];
    [self.searchDisplayController.searchResultsTableView reloadData];
    
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1/users/search.json"];
    NSDictionary *params = @{@"q":term};
    
    TWRequest *request = [[TWRequest alloc] initWithURL:url parameters:params requestMethod:TWRequestMethodGET];
    ACAccount *currentAccount = [self.accountsController currentAccount];
    [request setAccount:currentAccount];
    
    [request performRequestWithHandler:^(NSData *__strong responseData, NSHTTPURLResponse *__strong urlResponse, NSError *__strong error) {
        if([urlResponse statusCode] != 200){
            NSLog(@"error %i, %@", [urlResponse statusCode], [error localizedDescription]);
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            });
            return;
        }
        NSArray *returnedObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
        
        NSMutableArray *newResults = [NSMutableArray array];
        [returnedObject enumerateObjectsUsingBlock:^(__strong id obj, NSUInteger idx, BOOL *stop) {
            GOTwitterUser *user = [GOTwitterUser userWithDictionary:obj];
            [newResults addObject:user];
        }];
        [self.dataSource setResults:newResults];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.searchDisplayController.searchResultsTableView reloadData];
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
    GOTwitterUser *user = [self.dataSource objectAtIndexPath:indexPath];
    GOCompletionBlock block = ^(void){
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    };
    
    if(user.isFollowing){
        [user unfollowFromAccount:[self.accountsController currentAccount] andBlock:block];
    }else{
        [user followFromAccount:[self.accountsController currentAccount] andBlock:block];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -
#pragma mark UISearchDisplayControllerDelegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString{
    return NO;
}

@end