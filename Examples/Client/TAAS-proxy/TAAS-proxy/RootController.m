//
//  RootController.m
//  TAAS-proxy
//
//  TOTP example originally created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "RootController.h"
#import "AppDelegate.h"
#import "FXKeychain.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface RootController ()

@property (        nonatomic) BOOL                       readyP;
@property (        nonatomic) BOOL                       rememberedP;
@property (strong, nonatomic) NSDictionary              *sharedInfo;
@property (strong, nonatomic) NSURL                     *authURL;

@property (weak,   nonatomic) IBOutlet UILabel          *statusLabel;
@property (weak,   nonatomic) IBOutlet UILabel          *userLabel;

@end


@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) != nil) {
        DDLogVerbose(@"Client Library v%@", [Client version]);

        FXKeychain *keyChain = [FXKeychain defaultKeychain];
        NSDictionary *info = (NSDictionary *)[keyChain objectForKey:@"lastSteward"];
        if (info != nil) {
            DDLogVerbose(@"lastSteward: %@", info);
            NSString *string = [info objectForKey:@"authURL"];

            self.sharedInfo = info;
            self.rememberedP = YES;
            [self connectToSteward:[[info objectForKey:@"ipAddresses"] objectAtIndex:0]
                          withPort:[info objectForKey:@"port"]
                        andAuthURL:((string.length > 0) ? [NSURL URLWithString:string] : nil)];
        }

        TAASClient *sharedClient = [TAASClient sharedClient];
        sharedClient.delegate = self;
        [sharedClient findService];
    }
    return self;
};

- (IBAction)scanQRcode:(id)sender {
    ScanController *scanner = [[ScanController alloc] initWithNibName:@"ScanController" bundle:nil];
    scanner.delegate = self;
    [self presentViewController:scanner animated:YES completion:NULL];
}

- (void)notifyUser:(NSString *)message
         withTitle:(NSString *)title {
    DDLogVerbose(@"notifyUser: %@ - %@", title, message);
    self.statusLabel.text = message;

    UIApplication *application = [UIApplication sharedApplication];
    AppDelegate *appDelegate = (AppDelegate *) application.delegate;
    if (application.applicationState == UIApplicationStateBackground) {
        [appDelegate backgroundNotify:message andTitle:title];
        return;
    }
}


- (void)connectToSteward:(NSString *)ipAddress
                withPort:(NSNumber *)port
              andAuthURL:(NSURL *)authURL {
    [self resetSteward];

    self.service = [[TAASClient alloc] initWithAddress:ipAddress
                                               andPort:port
                                            andAuthURL:authURL];
    self.service.delegate = self;
    self.readyP = NO;
    [self.service startMonitoring];

    [self notifyUser:[NSString stringWithFormat:@"steward at %@", ipAddress]
           withTitle:@"Connecting"];
};

- (void)rememberSteward {
    if ((self.sharedInfo == nil) || (self.rememberedP)) return;
    self.rememberedP = YES;

    NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:(self.sharedInfo.count + 1)];
    [info addEntriesFromDictionary:self.sharedInfo];
    [info setObject:(self.authURL != nil ? [self.authURL absoluteString] : @"") forKey:@"authURL"];

    FXKeychain *keyChain = [FXKeychain defaultKeychain];
    DDLogVerbose(@"set lastSteward: %@", info);
    [keyChain setObject:info forKey:@"lastSteward"];

    NSString *key;
    if ((key = [self.sharedInfo objectForKey:@"hostName"]) != nil) [keyChain setObject:info forKey:key];
    if ((key = [self.sharedInfo objectForKey:@"name"]) != nil) [keyChain setObject:info forKey:key];

    self.statusLabel.text = @"";
}

- (void)resetSteward {
    if (self.service == nil) return;

    self.service.delegate = nil;
    [self.service stopMonitoring];
    self.service = nil;
}

#pragma mark - TAASClientDelegate methods

- (void)foundService:(NSDictionary *)info {
    if (self.service != nil) {
// TBD: add to list for future use
      return;
    }

    NSArray *ipaddrs = [info objectForKey:@"ipAddresses"];
    if (ipaddrs.count == 0) {
        [self notifyUser:[NSString stringWithFormat:@"no addresses for %@", [info objectForKey:@"name"]]
                                          withTitle:@"Error"];
        return;
    }

    [self notifyUser:[NSString stringWithFormat:@"Found %@", [info objectForKey:@"hostName"]]
           withTitle:@"Found"];

    self.sharedInfo = info;
    self.rememberedP = NO;
    [self connectToSteward:[ipaddrs objectAtIndex:0]
                  withPort:[self.sharedInfo objectForKey:@"port"]
                andAuthURL:self.authURL];
}

- (void)didReceiveMonitor:(NSString *)message {
    if (!self.readyP) {
        NSError *error = nil;
        NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:kNilOptions
                                                                     error:&error];
        NSDictionary *oops = (NSDictionary *)[dictionary objectForKey:@"error"];
        if (oops != nil) {
	    [self resetSteward];

            NSString *diagnostic = [((NSDictionary *)oops) objectForKey:@"diagnostic"];
            if (diagnostic == nil) diagnostic = message;
            [self notifyUser:diagnostic withTitle:@"Error"];
// TBD: prompt user to scan QRcode
            return;
	}

	self.readyP = YES;
        [self rememberSteward];
        [self.service listDevices];
    }

// TBD: add to screen
}

- (void)didReceiveListing:(NSString *)message {
// TBD: parse and internalize
}


- (void)didNotFindService:(NSDictionary *)errorDict {
    [self notifyUser:@"steward not found" withTitle:@"Error"];
}

- (void)failedToMonitor:(NSError *)error {
    [self resetSteward];

    [self notifyUser:[NSString stringWithFormat:@"unable to connect to %@", [self.sharedInfo objectForKey:@"name"]]
                               withTitle:@"Error"];
}

- (void)doneMonitoring:(NSInteger)code {
    [self resetSteward];

    [self notifyUser:@"monitoring terminated" withTitle:@"Error"];
}


#pragma mark - ScanControllerDelegate methods

- (void)closedWithURL:(NSURL *)url {
    self.authURL = url;
    if (!self.sharedInfo) return;

    self.rememberedP = NO;
    [self connectToSteward:[[self.sharedInfo objectForKey:@"ipAddresses"] objectAtIndex:0]
                  withPort:[self.sharedInfo objectForKey:@"port"]
                andAuthURL:self.authURL];
}

@end
