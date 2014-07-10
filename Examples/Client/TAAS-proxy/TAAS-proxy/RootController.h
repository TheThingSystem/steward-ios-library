//
//  RootController.h
//  TAAS-proxy
//
//  TOTP example originally created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TAASClient.h"
#import "ScanController.h"
#import "TableViewCell.h"


@interface RootController : UIViewController <TAASClientDelegate,  ScanControllerDelegate,
                                              UITableViewDelegate, UITableViewDataSource,
                                              UIActionSheetDelegate>

@property (strong, nonatomic) TAASClient              *service;
@property (strong, nonatomic) IBOutlet UITableView    *tableView;
@property (strong, nonatomic) IBOutlet TableViewCell  *tableCell;


#define kWhoAmI          @"whoami"
#define kWhatAmI         @"whatami"

@property (strong, nonatomic) NSMutableDictionary     *entities;
@property (        nonatomic) BOOL                     customaryP;

@end
