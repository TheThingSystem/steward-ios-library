//
//  TAASClient.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 6/4/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "Client.h"


@protocol TAASClientDelegate <NSObject>

@required
- (void)foundService:(NSDictionary *)info;

- (void)didReceiveMonitor:(NSString *)message;

- (void)didReceiveListing:(NSString *)message;

@optional
- (void)didNotFindService:(NSDictionary *)errorDict;

- (void)failedToMonitor:(NSError *)error;
- (void)doneMonitoring:(NSInteger)code;

- (void)failedListing:(NSError *)error;
- (void)doneListing:(NSInteger)code;

@end


@interface TAASClient : NSObject

#define kHostName    @"hostName"
#define kName        @"name"
#define kIpAddresses @"ipAddresses"
#define kPort        @"port"
#define kTXT         @"txt"
#define kIssuer      @"issuer"


@property (weak,   nonatomic) id <TAASClientDelegate>    delegate;


+ (TAASClient *)sharedClient;

- (id) initWithAddress:(NSString *)address andPort:(NSNumber *)port andAuthURL:(NSURL *)authURL;

- (BOOL)authenticate;
- (void)setAuthenticate:(BOOL)onoff;
- (NSURL *)authURL;
- (void)setAuthURL:(NSURL *)url;

- (NSString *)serviceURI:(NSString *)path;

- (NSString *)authenticatorJSON;

- (void)findService;

- (void)startMonitoring;
- (void)stopMonitoring;

- (void)listDevices;

@end
