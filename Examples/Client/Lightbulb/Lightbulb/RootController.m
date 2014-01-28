//
//  RootController.m
//  Lightbulb
//
//  Created by Alasdair Allan on 26/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "RootController.h"
#import "Client.h"

@interface RootController ()

@end

@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    Client *client = [Client sharedClient];
    [client findSteward];
    self.statusLabel.text = @"Looking for steward";
    self.lightswitch.enabled = NO;
}

#pragma mark - Light Switch

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (IBAction)switched:(id)sender {
    Client *client = [Client sharedClient];
    if ( self.lightswitch.on == YES ) {
        //[client startMonitoringEvents];
        //[client availableDevices];
        
        NSString *device = @"device/lighting";
        NSString *request = @"on";
        NSString *parameters = @"{ \\\"brightness\\\": 100, \\\"color\\\": { \\\"model\\\": \\\"rgb\\\", \\\"rgb\\\": { \\\"r\\\": 255, \\\"g\\\": 255, \\\"b\\\": 255 }}}";
        [client performWithDevice:device andRequest:request andParameters:parameters];
        
    } else {
        //[client stopMonitoringEvents];

        NSString *device = @"device/lighting";
        NSString *request = @"off";
        [client performWithDevice:device andRequest:request andParameters:nil];
        
    }
    
}

#pragma mark - Client Delegate Methods

- (void)stewardFoundWithAddress:(NSString *)ipAddress {
    NSLog(@"stewardFoundWithAddress: %@", ipAddress);
    self.statusLabel.text = [NSString stringWithFormat:@"steward at %@", ipAddress];
    self.lightswitch.enabled = YES;
    
}

- (void)stewardNotFoundWithError:(NSError *)error {
    NSLog(@"stewardNotFoundWithError: %@", error);
    self.statusLabel.text = [NSString stringWithFormat:@"steward not found"];
    
}

-(void)recievedPerformResponse:(NSString *)message {
    NSLog(@"json = %@", message);
  
}

@end
