//
//  TableViewCell.h
//  TAAS-proxy
//
//  Created by Danny Goodman on 6/29/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>

#define MonitorCellReuseIdentifier   @"MonitorCell"

@interface TableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel      *cellTimeLabel;
@property (nonatomic, strong) IBOutlet UILabel      *cellText1Label;
@property (nonatomic, strong) IBOutlet UILabel      *cellText2Label;
@property (strong, nonatomic) IBOutlet UIImageView  *icon;

@end
