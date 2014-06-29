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
#import "MHPrettyDate.h"
#import "RequestUtils.h"
#import "TAASNetwork.h"
#import "DDLog.h"


#define kAllStewards @"_allStewards"
#define kLastSteward @"_lastSteward"

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

@property (        nonatomic) BOOL                       readyP;
@property (        nonatomic) BOOL                       rememberedP;
@property (strong, nonatomic) NSString                  *taasName;

@property (strong, nonatomic) NSString                  *taasCloud;
@property (strong, nonatomic) NSURL                     *authURL;

@property (strong, nonatomic) NSMutableDictionary       *entities;
@property (strong, nonatomic) NSDateFormatter           *utcFormatter;

@property (weak,   nonatomic) IBOutlet UILabel          *statusLabel;
@property (weak,   nonatomic) IBOutlet UITextField      *textConsole;

@end


@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) != nil) {
        DDLogVerbose(@"Client Library v%@", [Client version]);

        FXKeychain *keyChain = [FXKeychain defaultKeychain];
        NSString *lastSteward = [keyChain objectForKey:kLastSteward];
        NSDictionary *info = (lastSteward != nil) ? [keyChain objectForKey:lastSteward] : nil;
        if (info == nil) {
            NSArray *allStewards = [keyChain objectForKey:kAllStewards];
            if (allStewards != nil) info = [keyChain objectForKey:[allStewards objectAtIndex:0]];
        }
        if (info != nil) {
            NSString *string = [info objectForKey:@"authURL"];

            self.rememberedP = YES;
            [self connectToSteward:info
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
              andAuthURL:(NSURL *)authURL {
    [self resetSteward:false];

    NSString *address = [[info objectForKey:kIpAddresses] objectAtIndex:0];
    NSNumber *port = [info objectForKey:kPort];

    if (!self.rememberedP) [self rememberThisSteward:info lastP:true];
    self.rememberedP = false;

    NSString *issuer = nil;
    if (authURL != nil) {
        NSArray *array = [authURL.path componentsSeparatedByString:@"/"];
        if (array.count > 3) {
            issuer = [[[array objectAtIndex:(array.count - 4)] componentsSeparatedByString:@":"]
                           objectAtIndex:0];
        }
    }
    if ((issuer != nil)
            && ([TAASNetwork sharedInstance].fxReachabilityStatus
                    == FXReachabilityStatusReachableViaWiFi)) {
/* TODO: determine if we're on the same network or not; if so: issuer = nil;
 */

    }
    if (issuer != nil) return [self rendezvous:issuer withAuthURL:authURL];

    self.service = [[TAASClient alloc] initWithAddress:address
                                               andPort:port
                                            andAuthURL:authURL];
    self.service.delegate = self;
    self.readyP = NO;
    [self.service startMonitoring];

    self.taasName = [self hostName:info];
    [self notifyUser:[NSString stringWithFormat:@"steward at %@", address]
           withTitle:@"Connecting"];
};

- (void)resetSteward:(BOOL)lastP {
    if (lastP) {
        FXKeychain *keyChain = [FXKeychain defaultKeychain];
        [keyChain removeObjectForKey:kLastSteward];
    }

    if (self.service == nil) return;

    self.service.delegate = nil;
    [self.service stopMonitoring];
    self.service = nil;
}

- (BOOL)rememberThisSteward:(NSDictionary *)info
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
    self.taasCloud = issuer;
    self.authURL = authURL;

    NSURLRequest *request = [NSURLRequest requestWithURL:
                                          [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/",
                                                                         self.taasCloud]]];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                  delegate:self
                                                          startImmediately:NO];
    [connection start];
}

-                        (void)connection:(NSURLConnection *)connection
willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [challenge.sender
                 useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
    forAuthenticationChallenge:challenge];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)redirectResponse {
    if (redirectResponse == nil) return request;

    NSURL *redirect = [request URL];
    NSString *address = [redirect host];
    self.service = [[TAASClient alloc] initWithAddress:address
                                               andPort:[redirect port]
                                            andAuthURL:self.authURL];
    self.service.authenticate = YES;
    self.service.delegate = self;
    self.readyP = NO;
    [self.service startMonitoring];

    [self notifyUser:self.taasCloud withTitle:@"Connecting"];

    return nil;
}


- (void)connection:(NSURLConnection *)theConnection
didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    if ([httpResponse statusCode] != 307) {
        DDLogError(@"%s: statusCode=%ld, expecting 307", __FUNCTION__, (long)[httpResponse statusCode]);
        [self notifyUser:[NSString stringWithFormat:@"unable to connect to %@", self.taasCloud]
               withTitle:kError];
    }
}

- (void)connection:(NSURLConnection *)theConnection
    didReceiveData:(NSData *)data {
    DDLogWarn(@"TAAS rendezvous: %lu octets", (unsigned long)[data length]);
}

- (void)connection:(NSURLConnection *)theConnection
  didFailWithError:(NSError *)error {
    DDLogError(@"%s: %@: %@", __FUNCTION__, self.taasCloud, error);
    [self notifyUser:[NSString stringWithFormat:@"failed to connect to %@", self.taasCloud]
                                      withTitle:kError];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection {
}


#pragma mark - TAASClientDelegate methods

- (void)foundService:(NSDictionary *)info {
    NSString *name = [self hostName:info];

    if (self.service != nil) {
        if ([self rememberThisSteward:info lastP:false]) {
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

    [self connectToSteward:info andAuthURL:nil];
}

- (void)didReceiveMonitor:(NSString *)message {
      NSError *error = nil;
      NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
      NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:kNilOptions
                                                                   error:&error];

    if (!self.readyP) {
        NSDictionary *oops;
        if ((dictionary != nil) && ((oops = [dictionary objectForKey:@"error"]) != nil)) {
            [self resetSteward:true];

            NSString *diagnostic = [oops objectForKey:@"diagnostic"];
            if (diagnostic == nil) diagnostic = message;
            [self notifyUser:diagnostic withTitle:kError];
// TBD: prompt user to scan QRcode
            return;
        }

        self.readyP = YES;
        self.statusLabel.text = @"Connected";
        [self.service listDevices];

        NSDictionary *result = [dictionary objectForKey:@"result"];
        if (result != nil) {
            NSDictionary *client = [dictionary objectForKey:@"client"];
            if (client != nil) self.statusLabel.text = @"Authenticated";
            return;
        }
    }
    if (dictionary == nil) return;

    [dictionary enumerateKeysAndObjectsUsingBlock:^(id category, id values, BOOL *stop) {
        if ([category isEqual:@"notice"]) return;

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
                                            URI,                                             @"authURL",
                                           nil];

    if (self.service != nil) {
        if ([self rememberThisSteward:info lastP:false]) {
            [self notifyUser:[NSString stringWithFormat:@"Found %@", name] withTitle:@"Discovered"];
        }

        return;
    }

    [self connectToSteward:info andAuthURL:url];
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
