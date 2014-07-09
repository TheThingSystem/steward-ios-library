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


#define kAllStewards     @"_allStewards"
#define kLastSteward     @"_lastSteward"

#define kWhoAmI          @"whoami"
#define kWhatAmI         @"whatami"

#define kBackgroundDelay 5.0f
#define kBonjourDelay    3.0f
#define kNetworkDelay    1.0f

#define kWhenEntry       @"when"
#define kWhoEntry        kWhoAmI
#define kDataEntry       @"data"
#define kIkonEntry       @"ikon"

#define kPushNone        (     0)
#define kPushRefresh     (1 << 0)
#define kPushSort        (1 << 1)


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
    if (seconds ==  0) return @"now";
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
@property (strong, nonatomic) NSTimer                   *ticker;
@property (strong, nonatomic) NSArray                   *permissions;

// device status
@property (strong, nonatomic) NSMutableDictionary       *entities;
@property (strong, nonatomic) NSDateFormatter           *utcFormatter;

// network reachability
@property (        nonatomic) FXReachabilityStatus       fxReachabilityStatus;
@property (strong, nonatomic) NSArray                   *fxAddresses;

// UI
@property (weak,   nonatomic) IBOutlet UILabel          *statusLabel;
@property (weak,   nonatomic) IBOutlet UISegmentedControl *modeControl;
@property (strong, nonatomic) UIRefreshControl          *refreshControl;
@property (strong, nonatomic) NSMutableArray            *tableConsoleData;
@property (strong, nonatomic) NSMutableArray            *tableDevicesData;
@property (strong, nonatomic) NSMutableArray            *tableTasksData;
@property (strong, nonatomic) NSMutableArray            *currentDataTable;

@end


@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) != nil) {
        DDLogVerbose(@"Client Library v%@", [Client version]);

        self.fxReachabilityStatus = FXReachabilityStatusUnknown;
        UIApplication *application = [UIApplication sharedApplication];
        NSTimeInterval seconds = (application.applicationState == UIApplicationStateBackground)
                                      ? kBackgroundDelay : kBonjourDelay;
        [self setTimeout:seconds];

        TAASClient *sharedClient = [TAASClient sharedClient];
        sharedClient.delegate = self;
        [sharedClient findService];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(fxReachabilityStatusDidChange)
                                                     name:FXReachabilityStatusDidChangeNotification
                                                   object:nil];

        self.utcFormatter = [[NSDateFormatter alloc] init];
        [self.utcFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.zzz'Z'"];
        [self.utcFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];

        FXKeychain *keyChain = [FXKeychain defaultKeychain];
        NSMutableArray *allStewards = [keyChain objectForKey:kAllStewards];
        if (allStewards != nil) {
            allStewards = [allStewards mutableCopy];
            NSMutableArray *array = [NSMutableArray array];
            [allStewards enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
                NSDictionary *info = [keyChain objectForKey:value];
                if (info == nil) {
                    [array addObject:value];
                    DDLogVerbose(@"removing: %@=%@", value, info);
                    return;
                }

                NSArray *ipAddresses = [info objectForKey:kIpAddresses];
                if ((ipAddresses == nil)
                        || (ipAddresses.count < 1)
                        || ([info objectForKey:kPort] == nil)) {
                    [keyChain removeObjectForKey:value];
                    DDLogVerbose(@"removing: %@=%@", value, info);
                    return;
                }
            }];
            if (array.count > 0) {
                [allStewards removeObjectsInArray:array];
                [keyChain setObject:allStewards forKey:kAllStewards];
                DDLogVerbose(@"allStewards: %@", allStewards);
            }
        } else {
            [keyChain removeObjectForKey:kLastSteward];
        }
        NSString *lastSteward = [keyChain objectForKey:kLastSteward];
        if ((lastSteward != nil)
                && ((allStewards == nil) || ([allStewards indexOfObject:lastSteward] == NSNotFound))) {
            [keyChain removeObjectForKey:kLastSteward];
            DDLogVerbose(@"removing lastSteward=%@", lastSteward);
        }
    }
    return self;
};

// refresh the screen
- (void)applicationWillEnterForeground {
    if (self.ticker != nil) [self.ticker invalidate];
    self.ticker = [NSTimer scheduledTimerWithTimeInterval:3.0f
                                                   target:self
                                                 selector:@selector(ticktock:)
                                                 userInfo:nil
                                                   repeats:YES];
    [self ticktock:self.ticker];
}

// see if we need to start looking for the steward
- (void)applicationDidBecomeActive {
    if ((self.timer == nil) && (self.service == nil)) [self setTimeout];
}

// stop refreshing the screen
- (void)applicationWillResignActive {
    if (self.ticker != nil) [self.ticker invalidate];
    self.ticker = nil;
}

- (void)ticktock:(NSTimer *)timer {
    [self.tableView reloadData];
}

- (void)timeout:(NSTimer *)timer {
    self.timer = nil;

    if (self.service != nil) return;
    if (self.fxReachabilityStatus == FXReachabilityStatusNotReachable) {
        [self notifyUser:@"network unavailable" withTitle:kAttention];
        return;
    }

    NSDictionary *info = (NSDictionary *)[timer userInfo];
    if (info == nil) {
        FXKeychain *keyChain = [FXKeychain defaultKeychain];
        NSString *lastSteward = [keyChain objectForKey:kLastSteward];
        info = (lastSteward != nil) ? [keyChain objectForKey:lastSteward] : nil;
        if (info == nil) {
            NSArray *allStewards = [keyChain objectForKey:kAllStewards];
            if (allStewards != nil) info = [keyChain objectForKey:[allStewards objectAtIndex:0]];
        }
    }
    if (info == nil) {
        [self notifyUser:@"no stewards available" withTitle:kAttention];
        return;
    }

    [self connectToSteward:info localP:NO];
}

- (void)viewDidLoad {
    self.tableConsoleData = [NSMutableArray arrayWithCapacity:100];
    self.tableDevicesData = [NSMutableArray arrayWithCapacity:100];
    self.tableTasksData   = [NSMutableArray arrayWithCapacity:100];
    self.currentDataTable = self.tableConsoleData;

// the tableView is a IBOutlet
    UINib *tableViewCellNib = [UINib nibWithNibName:@"TableViewCell" bundle:[NSBundle mainBundle]];
    [self.tableView registerNib:tableViewCellNib forCellReuseIdentifier:MonitorCellReuseIdentifier];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = nil;
    [self.refreshControl addTarget:self
                            action:@selector(refreshPulled)
                  forControlEvents:UIControlEventValueChanged];
    NSMutableAttributedString *refreshString =
        [[NSMutableAttributedString alloc] initWithString:@"Pull To Reconnect"];
    [refreshString addAttributes:@{ NSForegroundColorAttributeName: [UIColor grayColor] }
                           range:NSMakeRange(0, refreshString.length)];
    self.refreshControl.attributedTitle = refreshString;

    UIView *refreshView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    [self.tableView insertSubview:refreshView atIndex:0];
    [refreshView addSubview:self.refreshControl];

    [self notifyUser:@"scanning network..." withTitle:kDiscovery];
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

    UIApplication *application = [UIApplication sharedApplication];
    AppDelegate *appDelegate = (AppDelegate *) application.delegate;
    if ((application.applicationState == UIApplicationStateBackground) && ([title isEqual:kError])) {
        [appDelegate backgroundNotify:message andTitle:title];
    }

    [self pushDataDictionary:@{ kWhenEntry : [self.utcFormatter stringFromDate:[NSDate date]]
                              , kDataEntry : [NSString stringWithFormat:@"%@\n%@", title, message]
                              }
                   ontoTable:self.tableConsoleData
                 withOptions:kPushRefresh];
}

- (void)connectToSteward:(NSDictionary *)info
                  localP:(BOOL)localP {
    [self resetSteward:NO];

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
    self.permissions = nil;
    [self.service startMonitoring];

    [self notifyUser:[NSString stringWithFormat:@"steward at %@", address] withTitle:kConnecting];
};

- (void)resetSteward:(BOOL)lastP {
    if ((lastP) && (self.taasConnection == nil)) {
        FXKeychain *keyChain = [FXKeychain defaultKeychain];
        [keyChain removeObjectForKey:kLastSteward];
    }

    NSMutableAttributedString *refreshString =
        [[NSMutableAttributedString alloc] initWithString:@"Pull To Retry"];
    [refreshString addAttributes:@{ NSForegroundColorAttributeName: [UIColor grayColor] }
                           range:NSMakeRange(0, refreshString.length)];
    self.refreshControl.attributedTitle = refreshString;

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

    return (!foundP);
}


#pragma mark - TAAS cloud

- (void)rendezvous:(NSString *)issuer
       withAuthURL:(NSURL *)authURL
{
    self.service = [[TAASClient alloc] init];
    self.taasIssuer = issuer;
    self.authURL = authURL;

    NSURLRequest *request = [NSURLRequest requestWithURL:
                                          [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/",
                                                                         self.taasIssuer]]];
    self.taasConnection = [[NSURLConnection alloc] initWithRequest:request
                                                          delegate:self
                                                  startImmediately:YES];
}

-                        (void)connection:(NSURLConnection *)connection
willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate.pinnedCertValidator != nil) {
        [appDelegate.pinnedCertValidator validateChallenge:challenge];
        return;
    }

    [challenge.sender
                 useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
    forAuthenticationChallenge:challenge];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)redirectResponse {
    if (redirectResponse == nil) return request;

    NSString *taasIssuer = self.taasIssuer;
    NSURL *authURL = self.authURL;

    [self resetSteward:NO];

    NSURL *redirect = [request URL];
    NSString *address = [redirect host];
    self.service = [[TAASClient alloc] initWithAddress:address
                                               andPort:[redirect port]
                                            andAuthURL:authURL];
    self.service.authenticate = YES;
    self.service.delegate = self;
    self.monitoringP = NO;
    self.permissions = nil;
    [self.service startMonitoring];

    NSString *name = taasIssuer;
    NSRange range = [name rangeOfString:@"."];
    if (range.location != NSNotFound) name = [name substringToIndex:range.location];
    [self notifyUser:[NSString stringWithFormat:@"rendezvous %@", name]  withTitle:kConnecting];

    return nil;
}

- (void)connection:(NSURLConnection *)theConnection
didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    if ([httpResponse statusCode] != 307) {
        DDLogError(@"statusCode=%ld, expecting 307", (long)[httpResponse statusCode]);
        [self notifyUser:[NSString stringWithFormat:@"unable to connect to %@", self.taasIssuer]
               withTitle:kError];
        [self resetSteward:NO];
    }
}

- (void)connection:(NSURLConnection *)theConnection
    didReceiveData:(NSData *)data {
    DDLogWarn(@"TAAS rendezvous: %lu octets", (unsigned long)[data length]);
    [self resetSteward:NO];
}

- (void)connection:(NSURLConnection *)theConnection
  didFailWithError:(NSError *)error {
    DDLogError(@"%@: %@", self.taasIssuer, error);
    [self notifyUser:[NSString stringWithFormat:@"failed to connect to %@", self.taasIssuer]
                                      withTitle:kError];
    [self resetSteward:NO];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection {
    [self resetSteward:NO];
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

    NSArray *ipaddrs = [info objectForKey:kIpAddresses];
    if (ipaddrs.count == 0) {
        [self notifyUser:[NSString stringWithFormat:@"no addresses for %@", name] withTitle:kError];
        return;
    }

    if (self.service != nil) {
        if ([self rememberSteward:info lastP:NO]) {
            [self notifyUser:[NSString stringWithFormat:@"found %@", name] withTitle:kDiscovery];
        }
        return;
    }

    [self notifyUser:[NSString stringWithFormat:@"found %@", name] withTitle:kDiscovery];
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
        NSMutableAttributedString *refreshString =
            [[NSMutableAttributedString alloc] initWithString:@"Pull To Reconnect"];
        [refreshString addAttributes:@{ NSForegroundColorAttributeName: [UIColor grayColor] }
                               range:NSMakeRange(0, refreshString.length)];
        self.refreshControl.attributedTitle = refreshString;
        [self deleteAllTableData];
        self.statusLabel.text = [NSString stringWithFormat:@"%@: %@", self.taasName, @"connected"];
        [self.service listDevices];

        NSDictionary *result = [dictionary objectForKey:@"result"];
        if (result != nil) {
            NSDictionary *client = [dictionary objectForKey:@"client"];
            if (client != nil) {
                self.statusLabel.text = [NSString stringWithFormat:@"%@: %@", self.taasName, @"authenticated"];
            }
            return;
        }
    }
    if ((dictionary == nil) && ([dictionary objectForKey:@"notice"] != nil)) return;

    [dictionary enumerateKeysAndObjectsUsingBlock:^(id category, id values, BOOL *stop) {
        if (([category isEqual:@"notice"]) && ([values isKindOfClass:[NSDictionary class]])) {
            self.permissions = [values objectForKey:@"permissions"];
            DDLogInfo(@"permissions: %@", self.permissions);
            return;
        }
        if (([category isEqual:@"notice"]) || (![values isKindOfClass:[NSArray class]])) return;

        if ([category isEqual:@".updates"]) {
            [values enumerateObjectsUsingBlock:^(NSDictionary *value, NSUInteger idx, BOOL *stop) {
                NSString *whoami = [value objectForKey:kWhoAmI];
                if (whoami == nil) return;

                [self.entities setObject:value forKey:whoami];
                [self updateDevice:value];
            }];
            [self pushDataDictionary:nil
                           ontoTable:self.tableDevicesData
                         withOptions:(kPushRefresh | kPushSort)];
            return;
        }

        [values enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
            NSString *level = [entry objectForKey:@"level"];
            if (([level isEqual:@"debug"]) || ([level isEqual:@"info"])) return;

            NSString *date = [entry objectForKey:@"date"];
            NSString *message = [entry objectForKey:@"message"];
            NSString *meta = ([entry objectForKey:@"meta"] == [NSNull null])
                                 ? @"" : [entry objectForKey:@"meta"];
            NSString *data = [self valuesPP:meta];
            if ((date.length == 0) || (message.length == 0)) return;

// TODO: more message simplification here...
            if ([data isEqual:@"[Circular]"]) return;

            NSRange range = [message rangeOfString:@"device/" options:NSAnchoredSearch];
            if (range.location == NSNotFound) {
                range = [message rangeOfString:@"place/" options:NSAnchoredSearch];
            }
            NSString *whoami = @"";
            if (range.location != NSNotFound) {
              range = [message rangeOfString:@" "];
              if (range.location != NSNotFound) whoami = [message substringToIndex:range.location];
            }

            NSLog(@"message=%@",message);
            NSString *output = [NSString stringWithFormat:@"%@\n%@", message, data];
            [self pushDataDictionary:@{ kWhenEntry : date
                                      , kDataEntry : output
                                      , kWhoEntry  : whoami
                                      }
                           ontoTable:self.tableConsoleData
                         withOptions:kPushNone];
        }];
    }];
    [self pushDataDictionary:nil ontoTable:self.tableConsoleData withOptions:(kPushRefresh | kPushSort)];
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
            [self updateDevice:entity];
        }];
    }];
    [self pushDataDictionary:nil ontoTable:self.tableDevicesData withOptions:(kPushRefresh | kPushSort)];
}

- (void)updateDevice:(NSDictionary *)entity {
    NSString *whoami = [entity objectForKey:kWhoAmI];
    NSRange range = [whoami rangeOfString:@"device/" options:NSAnchoredSearch];
    if (range.location == NSNotFound) {
        range = [whoami rangeOfString:@"/place/" options:NSAnchoredSearch];
    }
    if (range.location == NSNotFound) return;

    NSDictionary *info = [entity objectForKey:@"info"];
    NSString *date = [entity objectForKey:@"updated"];
    if (date == nil) date = [info objectForKey:@"lastSample"];
    if (![date isKindOfClass:[NSString class]]) {
        NSNumber *ms = (NSNumber *)date;
        NSDate *timestamp =
            ![date isKindOfClass:[NSNumber class]]
                ? [NSDate dateWithTimeIntervalSince1970:([ms doubleValue] / 1000)]
                : [NSDate date];
        date = [self.utcFormatter stringFromDate:timestamp];
        range = [date rangeOfString:@".GMTZ" options:(NSBackwardsSearch | NSAnchoredSearch)];
        if (range.location != NSNotFound) {
            date = [NSString stringWithFormat:@"%@.000Z", [date substringToIndex:range.location]];
        }
    }

    NSMutableDictionary *state = [[NSMutableDictionary alloc] initWithCapacity:info.count];
    [info enumerateKeysAndObjectsUsingBlock:^(id key, NSString *value, BOOL *stop) {
        if (([value isKindOfClass:[NSString class]])
                && ([value isEqualToString:@"********"])) return;
        NSArray *skip = @[ @"authorizeURL",
                           @"cycleTime",
                           @"email",
                           @"lastSample",
                           @"locations",
                           @"station"
                           ];
        if ([skip indexOfObject:key] != NSNotFound) return;
        if (([key isEqualToString:@"track"]) && ([value isKindOfClass:[NSDictionary class]])) {
            NSMutableDictionary *track = [value mutableCopy];
            [track removeObjectForKey:@"albumArtURI"];
            value = (id)track;
        }

        [state setObject:value forKey:key];
    }];
    NSString *data = [self valuesPP:state];
    NSString *whatami = [entity objectForKey:kWhatAmI];
    range = [whatami rangeOfString:@"/device/gateway/" options:NSAnchoredSearch];
    if (range.location == NSNotFound) {
        range = [whatami rangeOfString:@"/device/indicator/" options:NSAnchoredSearch];
    }
    if ((range.location != NSNotFound) || (state.count < 1) || (data == nil)) data = @"";

    NSString *output = [NSString stringWithFormat:@"%@: %@\n%@",
                                 [entity objectForKey:@"name"],
                                 [entity objectForKey:@"status"],
                                 data];

    [self.tableDevicesData enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
        if (![[value objectForKey:kWhoEntry] isEqualToString:whoami]) return;

        *stop = YES;
        [self.tableDevicesData removeObjectAtIndex:idx];
    }];

    [self pushDataDictionary:@{ kWhenEntry : date
                              , kDataEntry : output
                              , kWhoEntry  : whoami
                              }
                   ontoTable:self.tableDevicesData
                 withOptions:kPushNone];
}


- (void)didNotFindService:(NSDictionary *)errorDict {
  // the timer will catch this
}

- (void)failedToMonitor:(NSError *)error {
    [self resetSteward:true];

    [self notifyUser:[NSString stringWithFormat:@"unable to connect to %@", self.taasName]
           withTitle:kError];
}

- (void)doneMonitoring:(NSInteger)code {
    [self resetSteward:NO];

    [self notifyUser:[NSString stringWithFormat:@"%@: %@", self.taasName, @"disconnected"]
           withTitle:kError];
    if (self.monitoringP) [self setTimeout];
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
        if ([self rememberSteward:info lastP:NO]) {
            [self notifyUser:[NSString stringWithFormat:@"found %@", name] withTitle:kDiscovery];
        }
        return;
    }

    [self notifyUser:[NSString stringWithFormat:@"found %@", [self hostName:info]] withTitle:kConnecting];
    [self connectToSteward:info localP:NO];
}


#pragma mark - FXReachability

- (void)fxReachabilityStatusDidChange {
    FXReachabilityStatus prev = self.fxReachabilityStatus;
    int status;
    NSArray *choices = @[ @"unknown", @"notReachable", @"reachableViaWWAN", @"reachableViaWiFi" ];

    self.fxReachabilityStatus = [FXReachability sharedInstance].status;
    status = (int)self.fxReachabilityStatus + 1;
    DDLogVerbose(@"reachabilityStatusDidChange: %@",
                 (0 <= status) && (status < choices.count)
                     ? [choices objectAtIndex:status]
                     : [NSString stringWithFormat:@"%d (unknown status)", status]);

    NSMutableArray *addresses = nil;
    struct ifaddrs *addrs = NULL;
    if (getifaddrs(&addrs) != 0) {
      int errcode = errno;
      char strerrbuf[BUFSIZ];

      if (strerror_r(errcode, strerrbuf, sizeof strerrbuf - 1) != 0) {
          snprintf(strerrbuf, sizeof strerrbuf, "errno=%d", errcode);
      }
      DDLogError(@"getifaddrs failed: %@", [NSString stringWithUTF8String:strerrbuf]);
    } else {
        int count;
        struct ifaddrs *ifa;

        for (ifa = addrs, count = 0; ifa; ifa = ifa -> ifa_next, count++) continue;
        addresses = [[NSMutableArray alloc] initWithCapacity:count];

        for (ifa = addrs; ifa; ifa = ifa -> ifa_next) {
            if ((ifa -> ifa_flags & IFF_LOOPBACK)
                    || (!(ifa -> ifa_flags & IFF_UP))
                    || (ifa -> ifa_addr -> sa_family != AF_INET)) continue;

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

    if ((self.fxReachabilityStatus == prev)
            && (self.fxAddresses != nil)
            && ((addresses == nil) || ([self.fxAddresses isEqualToArray:addresses]))) return;

    self.fxAddresses = addresses;

    if (self.timer != nil) return;

    NSDictionary *info = nil;
    if (self.service != nil) {
        info = self.service.parameters;
        [self resetSteward:true];
    }

    if (self.fxReachabilityStatus == FXReachabilityStatusNotReachable) {
        [self notifyUser:@"network unavailable" withTitle:kAttention];
        return;
    }

    [self setTimeout];

    if (self.fxReachabilityStatus != FXReachabilityStatusReachableViaWWAN) {
        [[TAASClient sharedClient] findService];
    }
    [self notifyUser:@"reconfiguring network" withTitle:kAttention];
}


#pragma mark - miscellany

- (void)setTimeout {
    NSTimeInterval seconds = (self.fxReachabilityStatus != FXReachabilityStatusReachableViaWWAN)
                                  ? kBonjourDelay : kNetworkDelay;
    [self setTimeout:seconds];
}

- (void)setTimeout:(NSTimeInterval)seconds {
    if (self.timer != nil) [self.timer invalidate];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:seconds
                                                  target:self
                                                selector:@selector(timeout:)
                                                userInfo:nil
                                                 repeats:NO];
}

- (NSString *)hostName:(NSDictionary *)info {
    NSString *name = [info objectForKey:kHostName];
    NSRange range = [name rangeOfString:@"." options:(NSBackwardsSearch | NSAnchoredSearch)];
    if (range.location != NSNotFound) name = [name substringToIndex:range.location];
    range = [name rangeOfString:@".local" options:(NSBackwardsSearch | NSAnchoredSearch)];
    if (range.location != NSNotFound) name = [name substringToIndex:range.location];

    return name;
}

- (NSString *)valuesPP:(id)value {
    NSMutableString *result = [[NSMutableString alloc] init];

    if ([value isKindOfClass:[NSDictionary class]]) {
        [value enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            NSString *string = [self valuePP:value];
            if (string == nil) return;
            if ((string.length > 36) && ([key isEqualToString:@"body"])) return;

            char keystring[20];
            snprintf(keystring, sizeof keystring, "%s:", (const char *)[key UTF8String]);
            if (result.length > 0) [result appendString:@"\n"];
            [result appendFormat:@"%-16.16s %@", keystring, value];
        }];

        return result;
    }

    if ([value isKindOfClass:[NSDictionary class]]) {
        [value enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
            NSString *string = [self valuePP:value];
            if (string == nil) return;

            char keystring[20];
            snprintf(keystring, sizeof keystring, "%lu:", (unsigned long) idx);
            if (result.length > 0) [result appendString:@"\n"];
            [result appendFormat:@"%-3.3s %@", keystring, value]; 
       }];

        return result;
    }

    return [self valuePP:value];
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
            if ((string.length > 36) && ([key isEqualToString:@"body"])) return;
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


# pragma mark - segmented (mode) control

- (IBAction)setDisplayMode:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0:
        default:
            self.currentDataTable = self.tableConsoleData;
            break;
        case 1:
            self.currentDataTable = self.tableDevicesData;
            break;
        case 2:
            self.currentDataTable = self.tableTasksData;
            break;
    }
    [self.tableView reloadData];
}


#pragma mark - action sheets

- (IBAction)rootActionSheet:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@""
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:@"Clear History"
                                                    otherButtonTitles:@"Scan QR Code", nil];
    [actionSheet showFromBarButtonItem:sender animated:YES];
    actionSheet.tag = 0;
}

- (void)confirmActionSheet:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Are you sure?"
                                                             delegate:self
                                                    cancelButtonTitle:@"Cancel"
                                               destructiveButtonTitle:@"Clear History"
                                                    otherButtonTitles:nil];
    [actionSheet showInView:self.view];
    actionSheet.tag = 1;
}

-  (void)actionSheet:(UIActionSheet *)actionSheet
clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (actionSheet.tag) {
        // root action sheet
        case 0:
            switch (buttonIndex) {
                case 0:
                    [self confirmActionSheet:nil];
                    break;
                case 1:
                    [self scanQRcode:nil];
                    break;
                case 2:
                default:
                    break;
            }
            break;

        // confirm deletion action sheet
        case 1:
            switch (buttonIndex) {
                case 0:
                    [self deleteAllTableData];
                    break;
                case 1:
                default:
                    break;
            }
            break;

        default:
            break;
    }
}


#pragma mark - tableView dataSource

- (void)deleteAllTableData {
    [self.tableConsoleData removeAllObjects];
    [self.tableDevicesData removeAllObjects];
    [self.tableTasksData removeAllObjects];

    [self.tableView reloadData];
}

- (void)pushDataDictionary:(NSDictionary *)dictionary
                 ontoTable:(NSMutableArray *) tableArray
               withOptions:(unsigned long)options {
    if (dictionary != nil) [tableArray insertObject:dictionary atIndex:0];

    if ((options & kPushSort) && (tableArray.count > 1)) {
        NSMutableArray *array =
            [NSMutableArray arrayWithArray:[tableArray sortedArrayUsingComparator:^(NSDictionary *obj1,
                                                                                    NSDictionary *obj2) {
                  return [[obj2 objectForKey:kWhenEntry] compare:[obj1 objectForKey:kWhenEntry]];
                }]];

        BOOL updateCurrentTable = (self.currentDataTable == tableArray);
             if (self.tableConsoleData == tableArray) self.tableConsoleData = array;
        else if (self.tableDevicesData == tableArray) self.tableDevicesData = array;
        else                                          self.tableTasksData   = array;
        if (updateCurrentTable) self.currentDataTable = array;
        tableArray = array;
    }

    if ((options & kPushRefresh) && (self.currentDataTable == tableArray)) [self.tableView reloadData];
}

-    (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat rowHeight = 20;
    NSDictionary *tableEntry = [self.currentDataTable objectAtIndex:indexPath.row];

    UIFont *font = [UIFont systemFontOfSize:14.0f];
    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObject:font
                                                                forKey:NSFontAttributeName];
    NSAttributedString *attrString1 =
        [[NSAttributedString alloc] initWithString:[tableEntry objectForKey:kDataEntry]
                                        attributes:attrsDictionary];
    CGFloat label1Height =
        [attrString1 boundingRectWithSize:CGSizeMake([tableView frame].size.width - 65, 450)
                                  options:NSStringDrawingUsesLineFragmentOrigin
                                  context:nil].size.height;
    rowHeight += label1Height;

    return rowHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentDataTable.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MonitorCellReuseIdentifier forIndexPath:indexPath];

    if (self.currentDataTable.count <= indexPath.row) return cell;

    NSDictionary *tableEntry = [self.currentDataTable objectAtIndex:indexPath.row];

    NSString *date = [tableEntry objectForKey:kWhenEntry];
    if (date != nil) date = [MHPrettyDate shortPrettyDateFromDate:[self.utcFormatter dateFromString:date]];
    cell.cellTimeLabel.text = date;

    cell.cellText1Label.text = [tableEntry objectForKey:kDataEntry];

    NSString *ikon = [tableEntry objectForKey:kIkonEntry];
    NSString *imageName = (ikon != nil) ? ikon : @"place-home";
    NSString *whoami = (ikon == nil) ? [tableEntry objectForKey:kWhoEntry] : nil;
    NSDictionary *entry = (whoami != nil) ? [self.entities objectForKey:whoami] : nil;
    NSString *whatami = (entry != nil) ? [entry objectForKey:kWhatAmI] : nil;
    NSArray *components = (whatami != nil) ? [whatami componentsSeparatedByString:@"/"] : nil;
    if ((components != nil) && (components.count == 5)) {
        NSString *major = components[2], *minor = components[4];

        if ([major isEqualToString:@"climate"]) {
            major = @"sensor";
                 if ([minor isEqualToString:@"control"])   { minor = @"thermostat"; major = @"control"; }
            else if ([minor isEqualToString:@"monitor"])     minor = @"meteo";
            else if ([minor isEqualToString:@"temperature"]) minor = @"meteo";
            else if ([minor isEqualToString:@"sensor"])      minor = @"generic";
            else imageName = [NSString stringWithFormat:@"sensor-%@", minor];
        } else if ([major isEqualToString:@"lighting"]) {
                 if ([minor isEqualToString:@"rgb"])         minor = @"lightstrip";
            else if ([minor isEqualToString:@"color"])       minor = @"led";
        } else if ([major isEqualToString:@"motive"]) {
                 if ([minor isEqualToString:@"model-s"])     minor = @"vehicle";
        } else if ([major isEqualToString:@"sensor"]) {
                 if ([minor isEqualToString:@"sensortag"])   minor = @"generic";
            else if ([minor isEqualToString:@"spotter"])     minor = @"generic";
        }
        imageName = [NSString stringWithFormat:@"%@-%@", major, minor];
        NSMutableDictionary *info = [tableEntry mutableCopy];
        [info setObject:imageName forKey:kIkonEntry];
        [self.currentDataTable replaceObjectAtIndex:indexPath.row withObject:info];
    }
    cell.icon.image = [UIImage imageNamed:imageName];
    return cell;
}

-       (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *tableEntry = [self.currentDataTable objectAtIndex:indexPath.row];
    NSString *whoami = [tableEntry objectForKey:kWhoEntry];
    DDLogVerbose(@"clicked on row %ld for %@", (long)indexPath.row, whoami);

    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

// UIRefreshControl event processing

- (void)refreshPulled {
    [self.refreshControl endRefreshing];

    [self resetSteward:NO];
    [self setTimeout];
    [self notifyUser:(self.monitoringP ? @"reconnecting..." : @"retrying...")
           withTitle:kDiscovery];
}

@end
