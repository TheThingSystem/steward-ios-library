//
//  TAASClient.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 6/4/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASClient.h"
#import "AppDelegate.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface  TAASClient () <StewardDelegate, MonitorDelegate, DevicesDelegate>

@property (strong, nonatomic) Client                    *client;
@property (strong, nonatomic) Devices                   *manager;
@property (        nonatomic) BOOL                       managerP;
@property (        nonatomic) BOOL                       retryP;
@property (strong, nonatomic) Monitor                   *monitor;
@property (        nonatomic) BOOL                       monitorP;
@property (strong, nonatomic) NSNumber                  *portno;
@property (strong, nonatomic) Steward                   *steward;

@end


@implementation  TAASClient

+ (TAASClient *)sharedClient {
    static TAASClient *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{ shared = [[TAASClient alloc] init]; });
    return shared;
}

- (id) init {
    if ((self = [super init])) {
        self.steward = [[Steward alloc] init];
        self.steward.delegate = self;
    }
    return self;
}

- (id) initWithAddress:(NSString *)address
               andPort:(NSNumber *)port
            andAuthURL:(NSURL *)authURL {
  NSDictionary *parameters = [NSDictionary
                                  dictionaryWithObjectsAndKeys:
                                      [NSArray arrayWithObject:address], kIpAddresses,
                                      port,                              kPort,
                                      [authURL absoluteString],          kAuthURL,
                                      nil];

  return [self initWithParameters:parameters];
}

- (id) initWithParameters:(NSDictionary *)parameters {
    if ((self = [self init])) {
        self.parameters = parameters;

        self.client = [[Client alloc] init];
        NSString *authURI = [parameters objectForKey:kAuthURL];
        self.client.authURL = (authURI.length > 0) ? [NSURL URLWithString:authURI] : nil;
        self.client.debug = YES;

        self.steward.ipAddress = [[self.parameters objectForKey:kIpAddresses] objectAtIndex:0];
        self.portno = [self.parameters objectForKey:kPort];
        self.monitorP = NO;

        NSString *URI = [NSString stringWithFormat:@"wss://%@:%hu/console", self.steward.ipAddress,
                                  [self.portno unsignedShortValue]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URI]];
        [request setNetworkServiceType:NSURLNetworkServiceTypeVoIP];
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        if (appDelegate.pinnedCertValidator != nil) {
            request.SR_SSLPinnedCertificates = appDelegate.pinnedCertValidator.trustedCertificates;
        }
        self.monitor = [[Monitor alloc] initWithURLRequest:request];
        self.monitor.delegate = self;
    }
    return self;
}

- (BOOL)authenticate {
    return self.client.authenticate;
}

- (void)setAuthenticate:(BOOL)onoff {
    self.client.authenticate = onoff;
}

- (NSURL *)authURL {
    return [self.client authURL];
}

- (void)setAuthURL:(NSURL *)url {
    [self.client setAuthURL:url];
}


- (NSString *)serviceURI:(NSString *)path {
    if (self.steward.ipAddress == nil) return nil;

    int portno = [self.portno intValue];
    return [NSString stringWithFormat:@"http%@://%@:%@%@",
                     ((portno != 80) && (portno != 8887)) ? @"s" : @"",
                     self.steward.ipAddress, self.portno, path];
}


- (NSString *)authenticatorJSON {
#define AUTHENTICATE_USER \
        @"{\"path\":\"/api/v1/user/authenticate/%@\",\"requestID\":\"%d\",\"response\":\"%@\"}"

    self.client.requestCounter++;
    return [NSString stringWithFormat:AUTHENTICATE_USER,
                     self.client.clientID, self.client.requestCounter, [self.client generateTOTP]];
}


- (void)findService {
    [self.steward findSteward];
}


- (void)startMonitoring {
    [self.monitor startMonitoringEvents];
}

- (void)listDevices {
    if (self.manager == nil) {
        self.managerP = NO;

        NSString *URI = [NSString stringWithFormat:@"wss://%@:%hu/manage", self.steward.ipAddress,
                                  [self.portno unsignedShortValue]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URI]];
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        if (appDelegate.pinnedCertValidator != nil) {
            request.SR_SSLPinnedCertificates = appDelegate.pinnedCertValidator.trustedCertificates;
        }
        self.manager = [[Devices alloc] initWithURLRequest:request];
        self.manager.delegate = self;
        self.manager.oneShotP = NO;
    }
    [self.manager listAllDevices];
}

- (void)stopManaging {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:2];
    if (self.monitor != nil) {
        [self.monitor stopMonitoringEvents];
        [array addObject:self.monitor];
    }
    if (self.manager != nil) {
        [self.manager stopListingDevices];
        [array addObject:self.manager];
    }

// avoid race conditions between SRWebSocket, blocks, and ARC...
    [NSTimer scheduledTimerWithTimeInterval:3.0f
                                     target:self
                                   selector:@selector(drained:)
                                   userInfo:array
                                   repeats:NO];
}

- (void)drained:(NSTimer *)timer {
    NSMutableArray *array = [timer userInfo];
    DDLogVerbose(@"drained: %@", array);
}

#pragma mark - StewardDelegate methods

- (void)stewardFoundWithAddress:(NSString *)ipAddress {
    DDLogError(@"%s: should never be invoked!", __FUNCTION__);
}

- (void)stewardFoundAtService:(NSNetService *)service {
    NSDictionary *txt = [NSNetService dictionaryFromTXTRecordData:[service TXTRecordData]];
    NSMutableDictionary *utf8 = [NSMutableDictionary dictionaryWithCapacity:txt.count];
    for (NSString *key in txt) {
        NSString *value = [[NSString alloc] initWithData:[txt objectForKey:key]
                                                encoding:NSUTF8StringEncoding];
        if (value == nil) {
            DDLogError(@"invalid encoding for TXT %@", key);
            continue;
        }
        [utf8 setObject:value forKey:key];
    }

    NSMutableDictionary *info = [NSMutableDictionary
                                     dictionaryWithObjectsAndKeys:
                                          service.hostName,                               kHostName,
                                          service.name,                                   kName,
                                          [service ipAddresses],                          kIpAddresses,
                                          [NSNumber numberWithUnsignedLong:service.port], kPort,
                                          [NSDictionary dictionaryWithDictionary:utf8],   kTXT,
                                          nil];
    if (self.delegate == nil) return;

    [self.delegate foundService:info];
}

- (void)stewardDidStopSearching {
    if ((self.delegate == nil)
            || (![self.delegate respondsToSelector:@selector(didNotFindService:)])) return;

    [self.delegate didNotFindService:nil];
}

- (void)stewardNotSearchedWithErrorDict:(NSDictionary *)errorDict {
    if ((self.delegate == nil)
            || (![self.delegate respondsToSelector:@selector(didNotFindService:)])) return;

    [self.delegate didNotFindService:errorDict];
}

- (void)stewardNotResolvedWithErrorDict:(NSDictionary *)errorDict {
    if ((self.delegate == nil)
            || (![self.delegate respondsToSelector:@selector(didNotFindService:)])) return;

    [self.delegate didNotFindService:errorDict];
}


#pragma mark - MonitorDelegate methods

- (void)receivedEventMessage:(NSString *)message {
    if ((!self.monitorP)
            && (self.client.authenticate)
            && ([message rangeOfString:@"error"].location != NSNotFound)) {
        self.monitorP = YES;
        [self.monitor.webSocket send:[self authenticatorJSON]];
        return;
    }

    if ((self.delegate == nil)
            || (![self.delegate respondsToSelector:@selector(didReceiveMonitor:)])) return;

    [self.delegate didReceiveMonitor:message];
}

- (void)monitoringFailedWithError:(NSError *)error {
    if ((self.delegate == nil)
            || (![self.delegate respondsToSelector:@selector(failedToMonitor:)])) return;

    [self.delegate failedToMonitor:error];
}

- (void)monitoringClosedWithCode:(NSInteger)code {
    if ((self.delegate == nil)
            || (![self.delegate respondsToSelector:@selector(doneMonitoring:)])) return;

    [self.delegate doneMonitoring:code];
}


#pragma mark - DevicesDelegate methods

- (void)receivedDeviceList:(NSString *)message {
    if ((!self.managerP)
            && (self.client.authenticate)
            && ([message rangeOfString:@"error"].location != NSNotFound)) {
        self.managerP = YES;
        self.retryP = YES;
        [self.manager.webSocket send:[self authenticatorJSON]];
        return;
    }

    if (self.retryP) {
        self.retryP = NO;
        [self.manager listAllDevices];
        return;
    }

    if ((self.delegate == nil)
            || (![self.delegate respondsToSelector:@selector(didReceiveListing:)])) return;

    [self.delegate didReceiveListing:message];
}

- (void)listingFailedWithError:(NSError *)error {
    if ((self.delegate == nil) || (![self.delegate respondsToSelector:@selector(failedListing:)])) return;

    [self.delegate failedListing:error];
}

- (void)listingClosedWithCode:(NSInteger)code {
    if ((self.delegate == nil) || (![self.delegate respondsToSelector:@selector(doneListing:)])) return;

    [self.delegate doneListing:code];
}

@end
