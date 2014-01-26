//
//  RootController.h
//  Lightbulb
//
//  Created by Alasdair Allan on 26/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Client.h"

@interface RootController : UIViewController <ClientDelegate>

@property (weak, nonatomic) IBOutlet UISwitch *lightswitch;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

- (IBAction)switched:(id)sender;

@end
