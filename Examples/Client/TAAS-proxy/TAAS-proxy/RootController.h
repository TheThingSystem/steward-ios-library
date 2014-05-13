//
//  RootController.h
//  TAAS-proxy
//
//  TOTP example created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Client.h"
#import "ScanController.h"

@interface RootController : UIViewController <ClientDelegate, ScanControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel    *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel    *totpLabel;
@property (weak, nonatomic) IBOutlet UILabel    *userLabel;

- (IBAction)scanQRcode:(id)sender;

@end
