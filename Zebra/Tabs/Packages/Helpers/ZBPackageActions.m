//
//  ZBPackageActions.m
//  Zebra
//
//  Created by Thatchapon Unprasert on 13/5/2019
//  Copyright © 2019 Wilson Styres. All rights reserved.
//

#import "ZBPackageActions.h"
#import "ZBPackage.h"

#import <ZBDevice.h>
#import <ZBAppDelegate.h>
#import <Sources/Helpers/ZBSource.h>
#import <Packages/Views/ZBPackageTableViewCell.h>
#import <Packages/Controllers/ZBPackageDepictionViewController.h>
#import <Queue/ZBQueue.h>
#import <UIColor+GlobalColors.h>
#import <Packages/Controllers/ZBPackageListTableViewController.h>
#import <Extensions/UIAlertController+Show.h>
#import <JSONParsing/ZBPurchaseInfo.h>

@implementation ZBPackageActions

#pragma mark - Package Actions

+ (void)performAction:(ZBPackageActionType)action forPackage:(ZBPackage *)package {
    [self performAction:action forPackage:package checkPayment:YES];
}

+ (void)performAction:(ZBPackageActionType)action forPackage:(ZBPackage *)package checkPayment:(BOOL)checkPayment {
    if (!package) return;
    if (action < ZBPackageActionInstall || action > ZBPackageActionHideUpdates) return;
    if (@available(iOS 11.0, *)) {
        if (checkPayment && action < ZBPackageActionShowUpdates && [package mightRequirePayment]) { // No need to check for authentication on show/hide updates
            if (@available(iOS 11.0, *)) {
                [package purchaseInfo:^(ZBPurchaseInfo * _Nonnull info) {
                    if (info && info.purchased && info.available) { // Either the package does not require authorization OR the package is purchased and available.
                        [self performAction:action forPackage:package checkPayment:NO];
                    }
                    else if (!info.available) { // Package isn't available.
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Package not available", @"") message:NSLocalizedString(@"This package is no longer for sale and cannot be downloaded.", @"") preferredStyle:UIAlertControllerStyleAlert];
                        
                        UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"") style:UIAlertActionStyleDefault handler:nil];
                        [alert addAction:ok];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [alert show];
                        });
                    }
                    else if (!info.purchased) { // Package isn't purchased, purchase it.
                        [package purchase:^(BOOL success, NSError * _Nullable error) {
                            if (success && !error) {
                                [self performAction:action forPackage:package];
                            }
                            else if (error) {
                                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Unable to complete purchase", @"") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                                
                                UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", @"") style:UIAlertActionStyleDefault handler:nil];
                                [alert addAction:ok];
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [alert show];
                                });
                            }
                        }];
                    }
                    else { // Fall-through, this will not check for payment info again.
                        [self performAction:action forPackage:package checkPayment:NO];
                    }
                }];
            }
            else {
                [self performAction:action forPackage:package checkPayment:NO];
            }
            return;
        }
    }
    
    switch (action) {
        case ZBPackageActionInstall:
            [self install:package];
            break;
        case ZBPackageActionRemove:
            [self remove:package];
            break;
        case ZBPackageActionReinstall:
            [self reinstall:package];
            break;
        case ZBPackageActionUpgrade:
            [self upgrade:package];
            break;
        case ZBPackageActionDowngrade:
            [self downgrade:package];
            break;
        case ZBPackageActionShowUpdates:
            [self showUpdatesFor:package];
            break;
        case ZBPackageActionHideUpdates:
            [self hideUpdatesFor:package];
            break;
    }
}

+ (void)install:(ZBPackage *)package {
    [[ZBQueue sharedQueue] addPackage:package toQueue:ZBQueueTypeInstall];
}

+ (void)remove:(ZBPackage *)package {
    [[ZBQueue sharedQueue] addPackage:package toQueue:ZBQueueTypeRemove];
}

+ (void)reinstall:(ZBPackage *)package {
    [[ZBQueue sharedQueue] addPackage:package toQueue:ZBQueueTypeReinstall];
}

+ (void)upgrade:(ZBPackage *)package {
    NSArray *greaterVersions = [package greaterVersions];
    if ([greaterVersions count] > 1) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select Version", @"") message:NSLocalizedString(@"Select a version to upgrade to:", @"") preferredStyle:UIAlertControllerStyleActionSheet];
        
        for (ZBPackage *otherPackage in greaterVersions) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:[otherPackage version] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[ZBQueue sharedQueue] addPackage:otherPackage toQueue:ZBQueueTypeUpgrade];
            }];
            
            [alert addAction:action];
        }
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancel];
        
        [alert show];
    }
    else {
        ZBPackage *upgrade = [greaterVersions count] == 1 ? greaterVersions[0] : package;
        [[ZBQueue sharedQueue] addPackage:upgrade toQueue:ZBQueueTypeUpgrade];
    }
}

+ (void)downgrade:(ZBPackage *)package {
    NSArray *lesserVersions = [package lesserVersions];
    if ([lesserVersions count] > 1) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select Version", @"") message:NSLocalizedString(@"Select a version to downgrade to:", @"") preferredStyle:UIAlertControllerStyleActionSheet];
        
        for (ZBPackage *otherPackage in lesserVersions) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:[otherPackage version] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[ZBQueue sharedQueue] addPackage:otherPackage toQueue:ZBQueueTypeUpgrade];
            }];
            
            [alert addAction:action];
        }
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancel];
        
        [alert show];
    }
    else {
        ZBPackage *upgrade = [lesserVersions count] == 1 ? lesserVersions[0] : package;
        [[ZBQueue sharedQueue] addPackage:upgrade toQueue:ZBQueueTypeUpgrade];
    }
}

+ (void)showUpdatesFor:(ZBPackage *)package {
    [package setIgnoreUpdates:NO];
}

+ (void)hideUpdatesFor:(ZBPackage *)package {
    [package setIgnoreUpdates:YES];
}

#pragma mark - Display Actions

+ (void)barButtonItemForPackage:(ZBPackage *)package completion:(void (^)(UIBarButtonItem *barButton))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        UIBarButtonItemActionHandler handler = ^{
            NSArray <NSNumber *> *actions = [package possibleActions];
            if ([actions count] > 1) {
                UIAlertController *selectAction = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ (%@)", package.name, package.version] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                
                for (UIAlertAction *action in [ZBPackageActions alertActionsForPackage:package]) {
                    [selectAction addAction:action];
                }
                
                [selectAction show];
            }
            else {
                ZBPackageActionType action = actions[0].intValue;
                [self performAction:action forPackage:package];
            }
        };
        
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:[self buttonTitleForPackage:package] style:UIBarButtonItemStylePlain actionHandler:handler];
        if (@available(iOS 11.0, *)) {
            if ([package mightRequirePayment]) {
                [package purchaseInfo:^(ZBPurchaseInfo * _Nonnull info) {
                    if (info) { // Package does have purchase info
                        if (!info.purchased && ![package isInstalled:NO]) { // If the user has not purchased the package
                            UIBarButtonItem *purchaseButton = [[UIBarButtonItem alloc] initWithTitle:info.price style:UIBarButtonItemStylePlain actionHandler:^{
                                [self performAction:ZBPackageActionInstall forPackage:package];
                            }];
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(purchaseButton);
                            });
                            return;
                        }
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(button);
                    });
                    return;
                }];
                return;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(button);
        });
        return;
    });
}

+ (NSArray <UITableViewRowAction *> *)rowActionsForPackage:(ZBPackage *)package inTableView:(UITableView *)tableView {
    NSMutableArray *rowActions = [NSMutableArray new];
    
    NSArray *actions = [package possibleActions];
    for (NSNumber *number in actions) {
        ZBPackageActionType action = number.intValue;
        if (action == ZBPackageActionShowUpdates || action == ZBPackageActionHideUpdates) continue;
        
        NSString *title = [self titleForAction:action useIcon:YES];
        UITableViewRowActionStyle style = action == ZBPackageActionRemove ? UITableViewRowActionStyleDestructive : UITableViewRowActionStyleNormal;
        UITableViewRowAction *rowAction = [UITableViewRowAction rowActionWithStyle:style title:title handler:^(UITableViewRowAction *rowAction, NSIndexPath *indexPath) {
            [self performAction:action forPackage:package];
            
            [tableView reloadRowsAtIndexPaths:[tableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
        }];
        
        [rowAction setBackgroundColor:[self colorForAction:action]];
        [rowActions addObject:rowAction];
    }
    
    return rowActions;
}

+ (NSArray <UIAlertAction *> *)alertActionsForPackage:(ZBPackage *)package {
    NSMutableArray <UIAlertAction *> *alertActions = [NSMutableArray new];
    
    NSArray *actions = [package possibleActions];
    for (NSNumber *number in actions) {
        ZBPackageActionType action = number.intValue;
        
        NSString *title = [self titleForAction:action useIcon:NO];
        UIAlertActionStyle style = action == ZBPackageActionRemove ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
        UIAlertAction *alertAction = [UIAlertAction actionWithTitle:title style:style handler:^(UIAlertAction *alertAction) {
            [self performAction:action forPackage:package];
        }];
        [alertActions addObject:alertAction];
    }
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:NULL];
    [alertActions addObject:cancel];
    
    return alertActions;
}

+ (NSArray <UIPreviewAction *> *)previewActionsForPackage:(ZBPackage *)package inTableView:(UITableView *_Nullable)tableView {
    NSMutableArray <UIPreviewAction *> *previewActions = [NSMutableArray new];
    
    NSArray *actions = [package possibleActions];
    for (NSNumber *number in actions) {
        ZBPackageActionType action = number.intValue;
        
        NSString *title = [self titleForAction:action useIcon:NO];
        UIPreviewActionStyle style = action == ZBPackageActionRemove ? UIPreviewActionStyleDestructive : UIPreviewActionStyleDefault;
        UIPreviewAction *previewAction = [UIPreviewAction actionWithTitle:title style:style handler:^(UIPreviewAction *previewAction, UIViewController *previewViewController) {
            [self performAction:action forPackage:package];
            
            if (tableView) {
                [tableView reloadRowsAtIndexPaths:[tableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
            }
        }];
        
        [previewActions addObject:previewAction];
    }
    
    return previewActions;
}

+ (NSArray <UIAction *> *)menuElementsForPackage:(ZBPackage *)package inTableView:(UITableView *_Nullable)tableView API_AVAILABLE(ios(13.0)) {
    NSMutableArray <UIAction *> *uiActions = [NSMutableArray new];
    
    NSArray *actions = [package possibleActions];
    for (NSNumber *number in actions) {
        ZBPackageActionType action = number.intValue;
        
        NSString *title = [self titleForAction:action useIcon:NO];
        UIImage *image = [self systemImageForAction:action];
        
        UIAction *uiAction = [UIAction actionWithTitle:title image:image identifier:nil handler:^(__kindof UIAction *uiAction) {
            [self performAction:action forPackage:package];
            
            if (tableView) {
                [tableView reloadRowsAtIndexPaths:[tableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
            }
        }];
        [uiActions addObject:uiAction];
    }
    
    return uiActions;
}

#pragma mark - Displaying Actions to User

+ (UIColor *)colorForAction:(ZBPackageActionType)action {
    switch (action) {
        case ZBPackageActionInstall:
            return [UIColor systemTealColor];
        case ZBPackageActionRemove:
            return [UIColor systemPinkColor];
        case ZBPackageActionReinstall:
            return [UIColor systemOrangeColor];
        case ZBPackageActionUpgrade:
            return [UIColor systemBlueColor];
        case ZBPackageActionDowngrade:
            return [UIColor systemPurpleColor];
        default:
            return nil;
    }
}

+ (UIImage *)systemImageForAction:(ZBPackageActionType)action API_AVAILABLE(ios(13.0)) {
    NSString *imageName;
    switch (action) {
        case ZBPackageActionInstall:
            imageName = @"icloud.and.arrow.down";
            break;
        case ZBPackageActionRemove:
            imageName = @"trash";
            break;
        case ZBPackageActionReinstall:
            imageName = @"arrow.clockwise";
            break;
        case ZBPackageActionUpgrade:
            imageName = @"arrow.up";
            break;
        case ZBPackageActionDowngrade:
            imageName = @"arrow.down";
            break;
        case ZBPackageActionShowUpdates:
            imageName = @"eye";
            break;
        case ZBPackageActionHideUpdates:
            imageName = @"eye.slash";
            break;
    }
    
    UIImageSymbolConfiguration *imgConfig = [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightHeavy];
    return [UIImage systemImageNamed:imageName withConfiguration:imgConfig];
}

+ (NSString *)titleForAction:(ZBPackageActionType)action useIcon:(BOOL)icon {
    BOOL useIcon = icon && [ZBDevice useIcon];
    
    switch (action) {
        case ZBPackageActionInstall:
            return useIcon ? @"↓" : NSLocalizedString(@"Install", @"");
        case ZBPackageActionRemove:
            return useIcon ? @"╳" : NSLocalizedString(@"Remove", @"");
        case ZBPackageActionReinstall:
            return useIcon ? @"↺" : NSLocalizedString(@"Reinstall", @"");
        case ZBPackageActionUpgrade:
            return useIcon ? @"↑" : NSLocalizedString(@"Upgrade", @"");
        case ZBPackageActionDowngrade:
            return useIcon ? @"⇵" : NSLocalizedString(@"Downgrade", @"");
        case ZBPackageActionShowUpdates:
            return NSLocalizedString(@"Show Updates", @"");
        case ZBPackageActionHideUpdates:
            return NSLocalizedString(@"Hide Updates", @"");
        default:
            break;
    }
    return @"Undefined";
}

+ (NSString *)buttonTitleForPackage:(ZBPackage *)package {
    NSArray <NSNumber *> *actions = [package possibleActions];
    if ([actions count] > 1) {
        return NSLocalizedString(@"Modify", @"");
    }
    else {
        ZBPackageActionType action = actions[0].intValue;
        return [self titleForAction:action useIcon:NO];
    }
}

@end
