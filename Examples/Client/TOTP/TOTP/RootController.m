//
//  RootController.m
//  TOTP
//
//  Created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "RootController.h"

@interface RootController ()

@end

@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    Client *client = [Client sharedClient];
    [client findSteward];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)scanQRcode:(id)sender {
    ScanController *scanner = [[ScanController alloc] initWithNibName:@"ScanController" bundle:nil];
    scanner.delegate = self;
    [self presentViewController:scanner animated:YES completion:NULL];
}

#pragma mark - Client Delegate Methods

- (void)stewardFoundWithAddress:(NSString *)ipAddress {
    NSLog(@"stewardFoundWithAddress: %@", ipAddress);
    self.statusLabel.text = [NSString stringWithFormat:@"steward at %@", ipAddress];
    
}

- (void)stewardNotFoundWithError:(NSError *)error {
    NSLog(@"stewardNotFoundWithError: %@", error);
    self.statusLabel.text = [NSString stringWithFormat:@"steward not found"];
    
}

-(void)recievedPerformResponse:(NSString *)message {
    NSLog(@"json = %@", message);
    
}

-(void)displayTOTP {
    Client *client = [Client sharedClient];
    NSString *totp = client.generateTOTP;
    self.totpLabel.text = totp;
    
}

#pragma mark - ScanController Delegate Methods

- (void)closedWithSecret:(NSString *)secret {
    NSLog(@"closedWithSecret: %@", secret);
    Client *client = [Client sharedClient];
    client.secret = secret;
    NSTimer * timer = [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(displayTOTP) userInfo:nil repeats:YES];
    
}

- (void)closedWithoutSecret {
    NSLog(@"closedWithoutSecret");
    
}


@end
