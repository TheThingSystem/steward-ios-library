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
#import "FXReachability.h"
#import <ifaddrs.h>
#import <net/if.h>
#import <arpa/inet.h>
#import "MHPrettyDate.h"
#import "RequestUtils.h"
#import "DDLog.h"


#define kAllStewards @"_allStewards"
#define kLastSteward @"_lastSteward"

#define kAttention   @"Attention"
#define kError       @"Error"

#define kWhoAmI      @"whoami"
#define kWhatAmI     @"whatami"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface MHPrettyDate (TAAS)

+ (NSString *)shortPrettyDateFromDate:(NSDate *)date;

@end


@implementation MHPrettyDate (TAAS)

+ (NSString *)shortPrettyDateFromDate:(NSDate *)date {
    if (date == nil) return nil;

    NSInteger seconds = [date timeIntervalSinceNow];
    if (seconds <= -60) {
        return [MHPrettyDate prettyDateFromDate:date withFormat:MHPrettyDateShortRelativeTime];
    }
    if (seconds ==   0) return @"now";
    return [NSString stringWithFormat:@"%ld%@", (long)-seconds,
                     NSLocalizedStringFromTable(@"s", @"MHPrettyDate", nil)];
}
@end


@interface RootController ()

// if nothing from bonjour within 3 seconds
@property (strong, nonatomic) NSTimer                   *timer;

// for TAAS cloud
@property (strong, nonatomic) NSString                  *taasIssuer;
@property (strong, nonatomic) NSURLConnection           *taasConnection;
@property (strong, nonatomic) NSURL                     *authURL;


// when connecting
@property (strong, nonatomic) NSString                  *taasName;

// when monitoring
@property (        nonatomic) BOOL                       monitoringP;

// device status
@property (strong, nonatomic) NSMutableDictionary       *entities;
@property (strong, nonatomic) NSDateFormatter           *utcFormatter;

// network reachability
@property (        nonatomic) FXReachabilityStatus       fxReachabilityStatus;
@property (strong, nonatomic) NSArray                   *fxAddresses;

// UI
@property (weak,   nonatomic) IBOutlet UILabel          *statusLabel;
@property (weak,   nonatomic) IBOutlet UITextField      *textConsole;

@end


@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) != nil) {
        DDLogVerbose(@"Client Library v%@", [Client version]);

        self.fxReachabilityStatus = FXReachabilityStatusUnknown;
        self.timer =  [NSTimer scheduledTimerWithTimeInterval:3.0f
                                                       target:self
                                                     selector:@selector(timeout:)
                                                     userInfo:nil
                                                      repeats:NO];

        TAASClient *sharedClient = [TAASClient sharedClient];
        sharedClient.delegate = self;
        [sharedClient findService];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(fxReachabilityStatusDidChange)
                                                     name:FXReachabilityStatusDidChangeNotification
                                                   object:nil];
    }
    return self;
};

- (void)timeout:(NSTimer *)timer {
    self.timer = nil;

DDLogVerbose(@"timer reachability=%ld",  (long)self.fxReachabilityStatus);
    if (self.service != nil) return;
    if (self.fxReachabilityStatus == FXReachabilityStatusNotReachable) {
        [self notifyUser:@"network unavailable" withTitle:kAttention];
        return;
    }

    NSDictionary *info = (NSDictionary *)[timer userInfo];
    if (info == nil) {
        FXKeychain *keyChain = [FXKeychain defaultKeychain];
        NSString *lastSteward = [keyChain objectForKey:kLastSteward];
NSLog(@"lastSteward=%@",lastSteward);
        info = (lastSteward != nil) ? [keyChain objectForKey:lastSteward] : nil;
if(info!= nil)NSLog(@"lastSteward info=%@",info);
        if (info == nil) {
            NSArray *allStewards = [keyChain objectForKey:kAllStewards];
NSLog(@"allStewards=%@",allStewards);
            if (allStewards != nil) info = [keyChain objectForKey:[allStewards objectAtIndex:0]];
if(info!= nil)NSLog(@"allStewards info=%@",info);
        }
    }
    if (info == nil) {
        [self notifyUser:@"no stewards available" withTitle:kAttention];
        return;
    }

    [self connectToSteward:info localP:NO];
}


- (IBAction)scanQRcode:(id)sender {
    ScanController *scanner = [[ScanController alloc] initWithNibName:@"ScanController" bundle:nil];
    scanner.delegate = self;
    [self presentViewController:scanner animated:YES completion:NULL];
}

- (void)notifyUser:(NSString *)message
         withTitle:(NSString *)title {
    DDLogVerbose(@"notifyUser: %@ - %@", title, message);
    self.statusLabel.text = message;

    if (self.textConsole.text == nil) self.textConsole.text = @"";
    NSString *format = (self.textConsole.text.length > 0) ? @"\n%@: %@":  @"%@: %@";
    self.textConsole.text = [self.textConsole.text stringByAppendingFormat:format, title, message];

    UIApplication *application = [UIApplication sharedApplication];
    AppDelegate *appDelegate = (AppDelegate *) application.delegate;
    if (application.applicationState == UIApplicationStateBackground) {
        [appDelegate backgroundNotify:message andTitle:title];
        return;
    }
}

- (void)connectToSteward:(NSDictionary *)info
                  localP:(BOOL)localP {
    [self resetSteward:false];

    if (localP) [self rememberSteward:info lastP:true];
    self.taasName = [self hostName:info];

    NSString *authURI = [info objectForKey:kAuthURL];
    NSURL *authURL = (authURI.length > 0) ? [NSURL URLWithString:authURI] : nil;
    NSString *issuer = nil;
    if ((!localP) && (authURL != nil)) {
        NSArray *array = [authURI componentsSeparatedByString:@"/"];
        if (array.count > 3) {
            issuer = [[[array objectAtIndex:(array.count - 4)] componentsSeparatedByString:@":"]
                           objectAtIndex:0];
        }
    }
    if (issuer != nil) return [self rendezvous:issuer withAuthURL:authURL];

    NSString *address = [[info objectForKey:kIpAddresses] objectAtIndex:0];

    self.service = [[TAASClient alloc] initWithParameters:info];
    self.service.authenticate = authURL != nil;
    self.service.delegate = self;
    self.monitoringP = NO;
    [self.service startMonitoring];

    [self notifyUser:[NSString stringWithFormat:@"steward at %@", address]
           withTitle:@"Connecting"];
};

- (void)resetSteward:(BOOL)lastP {
  if ((lastP) && (self.taasConnection == nil)) {
        FXKeychain *keyChain = [FXKeychain defaultKeychain];
        [keyChain removeObjectForKey:kLastSteward];
    }

    if (self.service == nil) return;

    if (self.taasConnection != nil) {
      [self.taasConnection cancel];
      self.taasConnection = nil;
      return;
    }

    self.service.delegate = nil;
    [self.service stopManaging];

    self.service = nil;
}

- (BOOL)rememberSteward:(NSDictionary *)info
                  lastP:(BOOL)lastP {
    FXKeychain *keyChain = [FXKeychain defaultKeychain];
    NSString *name = [self hostName:info];

    NSMutableArray *allStewards = [keyChain objectForKey:kAllStewards];
    allStewards = (allStewards != nil) ? [allStewards mutableCopy]
                                       : [[NSMutableArray alloc] initWithCapacity:1];

    BOOL foundP = [allStewards indexOfObject:name] != NSNotFound;
    if (!foundP) {
      [allStewards insertObject:name atIndex:0];
      [keyChain setObject:allStewards forKey:kAllStewards];
    }

    if (lastP) [keyChain setObject:name forKey:kLastSteward];

    [keyChain setObject:info forKey:name];

    NSDictionary *txt = [info objectForKey:kTXT];
    name = (txt != nil) ? [txt objectForKey:kName] : nil;
    if (name != nil) [keyChain setObject:info forKey:name];

    return foundP;
}


#pragma mark - TAAS cloud

- (void)rendezvous:(NSString *)issuer
       withAuthURL:(NSURL *)authURL
{
    self.service = [[TAASClient alloc] init];
    self.taasIssuer = issuer;
    self.authURL = authURL;
NSLog(@"rendezvous issuer=%@ authURL=%@",issuer,authURL);

    NSURLRequest *request = [NSURLRequest requestWithURL:
                                          [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/",
                                                                         self.taasIssuer]]];
    self.taasConnection = [[NSURLConnection alloc] initWithRequest:request
                                                          delegate:self
                                                  startImmediately:YES];
}

-                        (void)connection:(NSURLConnection *)connection
willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [challenge.sender
                 useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
    forAuthenticationChallenge:challenge];
// TODO: use pinned cert files
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)redirectResponse {
    if (redirectResponse == nil) return request;

    NSString *taasIssuer = self.taasIssuer;
    NSURL *authURL = self.authURL;
NSLog(@"redirect issuer=%@ authURL=%@",taasIssuer,authURL);

    [self resetSteward:NO];

    NSURL *redirect = [request URL];
    NSString *address = [redirect host];
    self.service = [[TAASClient alloc] initWithAddress:address
                                               andPort:[redirect port]
                                            andAuthURL:authURL];
    self.service.authenticate = YES;
    self.service.delegate = self;
    self.monitoringP = NO;
    [self.service startMonitoring];

    [self notifyUser:taasIssuer withTitle:@"Connecting"];

    return nil;
}


- (void)connection:(NSURLConnection *)theConnection
didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    if ([httpResponse statusCode] != 307) {
        DDLogError(@"%s: statusCode=%ld, expecting 307", __FUNCTION__, (long)[httpResponse statusCode]);
        [self notifyUser:[NSString stringWithFormat:@"unable to connect to %@", self.taasIssuer]
               withTitle:kError];
        [self resetSteward:false];
    }
}

- (void)connection:(NSURLConnection *)theConnection
    didReceiveData:(NSData *)data {
    DDLogWarn(@"TAAS rendezvous: %lu octets", (unsigned long)[data length]);
    [self resetSteward:false];
}

- (void)connection:(NSURLConnection *)theConnection
  didFailWithError:(NSError *)error {
    DDLogError(@"%s: %@: %@", __FUNCTION__, self.taasIssuer, error);
    [self notifyUser:[NSString stringWithFormat:@"failed to connect to %@", self.taasIssuer]
                                      withTitle:kError];
    [self resetSteward:false];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection {
    [self resetSteward:false];
}


#pragma mark - TAASClientDelegate methods

- (void)foundService:(NSMutableDictionary *)info {
    FXKeychain *keyChain = [FXKeychain defaultKeychain];
    NSString *name = [self hostName:info];

    NSDictionary *prev = [keyChain objectForKey:name];
    if (prev != nil) {
        NSString *authURI = [prev objectForKey:kAuthURL];
        if (authURI != nil) [info setObject:authURI forKey:kAuthURL];
    }

    if (self.service != nil) {
        if ([self rememberSteward:info lastP:false]) {
            [self notifyUser:[NSString stringWithFormat:@"Found %@", name] withTitle:@"Discovered"];
        }
        return;
    }

    NSArray *ipaddrs = [info objectForKey:kIpAddresses];
    if (ipaddrs.count == 0) {
        [self notifyUser:[NSString stringWithFormat:@"no addresses for %@", name] withTitle:kError];
        return;
    }

    [self notifyUser:[NSString stringWithFormat:@"Found %@", name] withTitle:@"Discovered"];
    [self connectToSteward:info localP:YES];
}

- (void)didReceiveMonitor:(NSString *)message {
      NSError *error = nil;
      NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
      NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:kNilOptions
                                                                   error:&error];

    if (!self.monitoringP) {
        NSDictionary *oops;
        if ((dictionary != nil) && ((oops = [dictionary objectForKey:@"error"]) != nil)) {
            [self resetSteward:true];

            NSString *diagnostic = [oops objectForKey:@"diagnostic"];
            if (diagnostic == nil) diagnostic = message;
            [self notifyUser:diagnostic withTitle:kError];
            return;
        }

        self.monitoringP = YES;
        self.statusLabel.text = @"Connected";
        [self.service listDevices];

        NSDictionary *result = [dictionary objectForKey:@"result"];
        if (result != nil) {
            NSDictionary *client = [dictionary objectForKey:@"client"];
            if (client != nil) self.statusLabel.text = @"Authenticated";
            return;
        }
    }
    if ((dictionary == nil) && ([dictionary objectForKey:@"notice"] != nil)) return;

    [dictionary enumerateKeysAndObjectsUsingBlock:^(id category, id values, BOOL *stop) {
        if (([category isEqual:@"notice"]) || (![values isKindOfClass:[NSArray class]])) return;

        if ([category isEqual:@".updates"]) {
            [values enumerateObjectsUsingBlock:^(NSDictionary *value, NSUInteger idx, BOOL *stop) {
                NSString *whoami = [value objectForKey:kWhoAmI];
                if (whoami != nil) [self.entities setObject:value forKey:whoami];
            }];
            return;
        }

        if (self.utcFormatter == nil) {
            self.utcFormatter = [[NSDateFormatter alloc] init];
            [self.utcFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.zzz'Z'"];
            [self.utcFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        }
        [values enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
            NSString *level = [entry objectForKey:@"level"];
            if (([level isEqual:@"debug"]) || ([level isEqual:@"info"])) return;

            if (self.textConsole.text == nil) self.textConsole.text = @"";
            NSString *format = (self.textConsole.text.length > 0) ? @"\n%@: %@ %@":  @"%@: %@ %@";

            NSString *date = [entry objectForKey:@"date"];
            if (date != nil) {
                date = [MHPrettyDate shortPrettyDateFromDate:[self.utcFormatter dateFromString:date]];
            }

            NSString *meta = [entry objectForKey:@"meta"];
            NSString *data = [self valuePP:meta];

            self.textConsole.text = [self.textConsole.text
                                        stringByAppendingFormat:format, (date ? date : @""),
                                        [entry objectForKey:@"message"], (data ? data : @"")];
        }];
    }];
}

- (void)didReceiveListing:(NSString *)message {
    NSError *error = nil;
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&error];
    if (dictionary == nil) return;
    self.entities = nil;

    NSDictionary *oops;
    if ((dictionary != nil) && ((oops = [dictionary objectForKey:@"error"]) != nil)) {
        NSString *diagnostic = [oops objectForKey:@"diagnostic"];
        if (diagnostic == nil) diagnostic = message;
        [self notifyUser:diagnostic withTitle:kError];
        return;
    }

    self.entities = [[NSMutableDictionary alloc] init];
    NSDictionary *result = [dictionary objectForKey:@"result"];
    [result enumerateKeysAndObjectsUsingBlock:^(id entityType, id values, BOOL *stop) {
        if ([entityType isEqual:@"actors"]) return;

        [values enumerateKeysAndObjectsUsingBlock:^(id whoami, id value, BOOL *stop) {
            NSMutableDictionary *entity = [NSMutableDictionary dictionaryWithDictionary:value];
            [entity setObject:whoami forKey:kWhoAmI];
            [entity setObject:entityType forKey:kWhatAmI];
            [self.entities setObject:entity forKey:whoami];
        }];
    }];
}


- (void)didNotFindService:(NSDictionary *)errorDict {
    [self notifyUser:@"steward not found" withTitle:kError];
}

- (void)failedToMonitor:(NSError *)error {
    [self resetSteward:true];

    [self notifyUser:[NSString stringWithFormat:@"unable to connect to %@", self.taasName]
           withTitle:kError];
}

- (void)doneMonitoring:(NSInteger)code {
    [self resetSteward:false];

    [self notifyUser:@"monitoring terminated" withTitle:kError];
}


#pragma mark - ScanControllerDelegate methods

- (void)closedWithURL:(NSURL *)url {
    if (url == nil) {
        [self notifyUser:@"invalid QRcode: not a URL" withTitle:kError];
        return;
    }

    NSString *URI = [url absoluteString];
    NSArray *array = [URI componentsSeparatedByString:@"/"];
    if (array.count < 4) {
        [self notifyUser:@"invalid QRcode: missing issuer" withTitle:kError];
        return;
    }
    NSString *issuer = [[[array objectAtIndex:(array.count - 4)] componentsSeparatedByString:@":"]
                            objectAtIndex:0];

    NSDictionary *parameters = [URI URLQueryParameters];
    NSString *hostName = [parameters objectForKey:kHostName];
    NSString *name = [parameters objectForKey:kName];
    NSArray *ipAddresses = [[parameters objectForKey:kIpAddresses] componentsSeparatedByString:@","];
    NSString *port = [parameters objectForKey:kPort];
    if ((hostName == nil) || (name == nil) || (ipAddresses == nil) || (port == nil) || (issuer == nil)) {
        [self notifyUser:@"invalid QRcode: missing parameters" withTitle:kError];
        return;
    }

    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                           hostName,                                         kHostName,
                                           name,                                             kName,
                                           ipAddresses,                                      kIpAddresses,
                                           [NSNumber numberWithInteger:[port integerValue]], kPort,
                                           [NSDictionary dictionaryWithObjectsAndKeys:
                                                  issuer,                                    kName,
                                                  nil],                                      kTXT,
                                            URI,                                             kAuthURL,
                                           nil];
    if (self.service != nil) {
        if ([self rememberSteward:info lastP:false]) {
            [self notifyUser:[NSString stringWithFormat:@"Found %@", name] withTitle:@"Discovered"];
        }
        return;
    }

    [self connectToSteward:info localP:NO];
}


#pragma mark - FXReachability

- (void)fxReachabilityStatusDidChange {
    FXReachabilityStatus prev = self. fxReachabilityStatus;

    self.fxReachabilityStatus = [FXReachability sharedInstance].status;
    DDLogVerbose(@"reachability=%ld",  (long)self.fxReachabilityStatus);

    NSMutableArray *addresses = nil;
    struct ifaddrs *addrs = NULL;
    if (getifaddrs(&addrs) != 0) {
      DDLogError(@"%s: getifaddrs failed: errno=%d", __FUNCTION__, errno);
    } else {
        int count;
        struct ifaddrs *ifa;

        for (ifa = addrs, count = 0; ifa; ifa = ifa -> ifa_next, count++) continue;
        addresses = [[NSMutableArray alloc] initWithCapacity:count];

        for (ifa = addrs; ifa; ifa = ifa -> ifa_next) {
            if ((ifa -> ifa_flags & IFF_LOOPBACK) || (ifa -> ifa_addr -> sa_family != AF_INET)) continue;

            char ipaddr[INET_ADDRSTRLEN];
            struct sockaddr_in *sin = (struct sockaddr_in *) ifa -> ifa_addr;
            if (!inet_ntop(sin -> sin_family, &sin -> sin_addr, ipaddr, sizeof ipaddr)) continue;
            [addresses addObject:[NSString stringWithFormat:@"%s", ipaddr]];

            if (self.fxReachabilityStatus != FXReachabilityStatusReachableViaWiFi) {
                NSString *name = [NSString stringWithUTF8String:ifa->ifa_name];
                self.fxReachabilityStatus = [name hasPrefix:@"en"]
                                                ? FXReachabilityStatusReachableViaWiFi
                                                : FXReachabilityStatusReachableViaWWAN;
            }
        }

        if (addresses.count > 1) {
          addresses = [NSMutableArray
                           arrayWithArray:[addresses sortedArrayUsingComparator:^(NSString *obj1,
                                                                                  NSString *obj2) {
                return [obj1 compare:obj2];
            }]];
        }
    }
    if (addrs != NULL) freeifaddrs(addrs);

NSLog(@"reachability: previous=%ld current=%ld", (long)prev, (long)self.fxReachabilityStatus);
NSLog(@"addresses: previous=%@",self.fxAddresses);
NSLog(@"addresses:  current=%@",addresses);
    if ((self.fxReachabilityStatus == prev)
            && (self.fxAddresses != nil)
            && ((addresses == nil) || ([self.fxAddresses isEqualToArray:addresses]))) return;

    self.fxAddresses = addresses;

NSLog(@"timer=%@ service=%@",self.timer,self.service);
    if (self.timer != nil) {
        [self.timer fire];
        return;
    }

    NSDictionary *info = nil;
    if (self.service != nil) {
        info = self.service.parameters;
        [self resetSteward:true];
    }

    if (self.fxReachabilityStatus == FXReachabilityStatusNotReachable) {
        [self notifyUser:@"network unavailable" withTitle:kAttention];
        return;
    }

    NSTimeInterval seconds = (self.fxReachabilityStatus == FXReachabilityStatusReachableViaWWAN)
                                  ? 3.0f : 1.0f;
    self.timer =  [NSTimer scheduledTimerWithTimeInterval:seconds
                                                   target:self
                                                 selector:@selector(timeout:)
                                                 userInfo:info
                                                  repeats:NO];

    [[TAASClient sharedClient] findService];
    [self notifyUser:@"reconfiguring network" withTitle:kAttention];
}


#pragma mark - miscellany

- (NSString *)hostName:(NSDictionary *)info {
    NSString *name = [info objectForKey:kHostName];
    NSRange range = [name rangeOfString:@"." options:(NSBackwardsSearch | NSAnchoredSearch)];
    if (range.location != NSNotFound) name = [name substringToIndex:range.location];
    range = [name rangeOfString:@".local" options:(NSBackwardsSearch | NSAnchoredSearch)];
    if (range.location != NSNotFound) name = [name substringToIndex:range.location];

    return name;
}

- (NSString *)valuePP:(id)value {
    if ((value == nil) || ([value isKindOfClass:[NSNull class]])) return nil;

    if ([value isKindOfClass:[NSDictionary class]]) return [self dictionaryPP:value];
    if ([value isKindOfClass:[NSArray class]]) return [self arrayPP:value];
    if (![value isKindOfClass:[NSString class]]) return [NSString stringWithFormat:@"%@", value];

    NSError *error = nil;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&error];
    return (dictionary ? [self dictionaryPP:dictionary] : value);
}

- (NSString *)dictionaryPP:(NSDictionary *)dict {
    NSMutableString *result = [[NSMutableString alloc] init];

    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        NSString *string = [self valuePP:value];
        if (string != nil) {
            if (string.length > 36) {
                if ([key isEqualToString:@"body"]) return;
//              string = [[string substringWithRange:NSMakeRange(0, 32)] stringByAppendingString:@"..."];
            }
            [result appendFormat:((result.length > 0) ? @", %@:%@" : @"{%@:%@"), key, string];
        }
    }];
    if (result.length == 0) return nil;
    [result appendString:@"}"];

    return result;
}

- (NSString *)arrayPP:(NSArray *)array {
    NSMutableString *result = [[NSMutableString alloc] init];

    [array enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
        NSString *string = [self valuePP:value];
        if (string != nil) [result appendFormat:((result.length > 0) ? @", %@" : @"[%@"), string];
    }];
    if (result.length == 0) return nil;
    [result appendString:@"]"];

    return result;
}

@end
