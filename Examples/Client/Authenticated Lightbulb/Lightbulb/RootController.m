//
//  RootController.m
//  Lightbulb
//
//  Created by Alasdair Allan on 26/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "RootController.h"
#import "Client.h"
#import "ScanController.h"

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
    
    self.foundStewardLabel.textColor = [UIColor redColor];
    self.gotAuthLabel.textColor = [UIColor redColor];
    self.gotClientIDLabel.textColor = [UIColor redColor];
}

#pragma mark - Light Switch

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (IBAction)switched:(id)sender {
    Client *client = [Client sharedClient];
    client.authenticate = YES;
    if ( self.lightswitch.on == YES ) {
        
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

- (IBAction)scanQRcode:(id)sender {
    ScanController *scanner = [[ScanController alloc] initWithNibName:@"ScanController" bundle:nil];
    scanner.delegate = self;
    [self presentViewController:scanner animated:YES completion:NULL];
}

#pragma mark - Client Delegate Methods

- (void)stewardFoundWithAddress:(NSString *)ipAddress {
    NSLog(@"stewardFoundWithAddress: %@", ipAddress);
    self.statusLabel.text = [NSString stringWithFormat:@"steward at %@", ipAddress];
    self.lightswitch.enabled = YES;
    self.foundStewardLabel.textColor = [UIColor greenColor];
    
}

- (void)stewardNotFoundWithError:(NSError *)error {
    NSLog(@"stewardNotFoundWithError: %@", error);
    self.statusLabel.text = [NSString stringWithFormat:@"steward not found"];
    
}

-(void)recievedPerformResponse:(NSString *)message {
    NSLog(@"json = %@", message);
  
}

#pragma mark - ScanController Delegate Methods

- (void)closedWithURL:(NSURL*)url {
    NSLog(@"closedWithURL: %@", url);
    Client *client = [Client sharedClient];
    client.authURL = url;
    self.gotAuthLabel.textColor = [UIColor greenColor];
    self.gotClientIDLabel.textColor = [UIColor greenColor];
    self.clientField.text = client.clientID;
    
}

- (void)closedWithoutSecret {
    NSLog(@"closedWithoutSecret");
    
}

#pragma mark - UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationBeginsFromCurrentState:YES];
    self.view.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y-165.0, self.view.frame.size.width, self.view.frame.size.height);
    [UIView commitAnimations];
    return YES;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationBeginsFromCurrentState:YES];
    self.view .frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y+165.0,self.view.frame.size.width, self.view.frame.size.height);
    [UIView commitAnimations];
    return YES;
}
    

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    Client *client = [Client sharedClient];
    client.clientID = textField.text;
    NSLog(@"Client ID = %@", textField.text);
    self.gotClientIDLabel.textColor = [UIColor greenColor];
	[textField resignFirstResponder];
	return YES;
}

@end
