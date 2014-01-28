//
//  RootController.h
//  Lightbulb
//
//  Created by Alasdair Allan on 26/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Client.h"
#import "ScanController.h"

@interface RootController : UIViewController <ClientDelegate, ScanControllerDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UISwitch *lightswitch;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITextField *clientField;

@property (weak, nonatomic) IBOutlet UILabel *foundStewardLabel;
@property (weak, nonatomic) IBOutlet UILabel *gotAuthLabel;
@property (weak, nonatomic) IBOutlet UILabel *gotClientIDLabel;

- (IBAction)switched:(id)sender;
- (IBAction)scanQRcode:(id)sender;

@end
