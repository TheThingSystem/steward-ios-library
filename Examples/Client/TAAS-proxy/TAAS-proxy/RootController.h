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


@interface RootController : UIViewController <TAASClientDelegate, ScanControllerDelegate>

@property (strong, nonatomic) TAASClient         *service;

@end
