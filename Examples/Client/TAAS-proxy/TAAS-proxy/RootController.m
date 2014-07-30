//
//  RootController.m
//  TAAS-proxy
//
//  TOTP example originally created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <CoreTelephony/CTCallCenter.h>
#import "RootController.h"
#import "AppDelegate.h"
#import "TAASPrettyPrinter.h"
#import "FXKeychain.h"
#import "FXReachability.h"
#import <ifaddrs.h>
#import <net/if.h>
#import <arpa/inet.h>
#import "RequestUtils.h"
#import "DDLog.h"


#define kAllStewards     @"_allStewards"
#define kLastSteward     @"_lastSteward"

#define kBackgroundDelay 5.0f
#define kBonjourDelay    3.0f
#define kNetworkDelay    1.0f

#define kWhenEntry       @"when"
#define kWhoEntry        kWhoAmI
#define kDataEntry       @"data"
#define kIkonEntry       @"ikon"
#define kScriptInfo      @"script"

#define kPushNone        (     0)
#define kPushRefresh     (1 << 0)
#define kPushSort        (1 << 1)
#define kPushInvert      (1 << 2)


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


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
@property (strong, nonatomic) NSDateFormatter           *utcFormatter;

// activities
@property (strong, nonatomic) NSMutableDictionary       *groups;
@property (strong, nonatomic) NSMutableDictionary       *tasks;

// network reachability
@property (        nonatomic) FXReachabilityStatus       fxReachabilityStatus;
@property (strong, nonatomic) NSArray                   *fxAddresses;
@property (strong, nonatomic) CTCallCenter              *ctCallCenter;

// UI
@property (weak,   nonatomic) IBOutlet UILabel            *statusLabel;
@property (weak,   nonatomic) IBOutlet UISegmentedControl *modeControl;
@property (strong, nonatomic) UIRefreshControl            *refreshControl;
@property (strong, nonatomic) NSMutableArray              *tableConsoleData;
@property (strong, nonatomic) NSMutableArray              *tableDevicesData;
@property (strong, nonatomic) NSMutableArray              *tableTasksData;
@property (strong, nonatomic) NSMutableArray              *currentDataTable;
@property (strong, nonatomic) NSMutableDictionary         *actionSheetChoices;

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


        self.ctCallCenter = [[CTCallCenter alloc] init];
        self.ctCallCenter.callEventHandler = ^(CTCall *ctCall) {
            DDLogVerbose(@"callEventHander: %@", ctCall);

            CTCallCenter *callCenter = [[CTCallCenter alloc] init];
            NSSet *calls = [callCenter currentCalls];
            if ((calls != nil) || (calls.count > 0)) return;
            [[NSNotificationCenter defaultCenter]
                  postNotificationName:FXReachabilityStatusDidChangeNotification object:nil];
        };

        // sometimes when prototyping, it helps to have sanity-checking...
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

    FXKeychain *keyChain = [FXKeychain defaultKeychain];

    NSDictionary *info = (NSDictionary *)[timer userInfo];
    // if we're now on a mobile network, verify we have credentials
    if ((info != nil)
            && (self.fxReachabilityStatus == FXReachabilityStatusReachableViaWWAN)
            && ([self issuer:info] == nil)) info = nil;
    if (info == nil) {
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

    // ditto
    if ((self.fxReachabilityStatus != FXReachabilityStatusReachableViaWWAN)
            || ([self issuer:info] != nil)) {
        [self connectToSteward:info localP:NO];
        return;
    }

    // find a steward for which we have credentials
    BOOL foundP, *fptr;
    foundP = NO;
    fptr = &foundP;
    NSArray *allStewards = [keyChain objectForKey:kAllStewards];
    if (allStewards != nil) {
        [allStewards enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
            NSDictionary *info = [keyChain objectForKey:value];
            if ((info == nil) || ([self issuer:info] == nil)) return;

            [self connectToSteward:info localP:NO];
            *fptr = YES;
            *stop = YES;
        }];
    }

    if (!foundP) [self notifyUser:@"no stewards available for rendezvous" withTitle:kAttention];
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
    self.taasName = [self serverName:info];

    NSString *authURI = [info objectForKey:kAuthURL];
    NSURL *authURL = (authURI.length > 0) ? [NSURL URLWithString:authURI] : nil;
    NSString *issuer = (!localP) ? [self issuer:info] : nil;
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
                                       : [NSMutableArray arrayWithCapacity:1];

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

    name = [self serverName:info];
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

- (void)didReceiveMonitor:(NSDictionary *)dictionary {
    if (!self.monitoringP) {
        NSDictionary *oops;
        if ((dictionary != nil) && ((oops = [dictionary objectForKey:@"error"]) != nil)) {
            [self resetSteward:true];

            NSString *diagnostic = [oops objectForKey:@"diagnostic"];
            if (diagnostic == nil) diagnostic = @"invalid response";
            [self notifyUser:diagnostic withTitle:kError];
            return;
        }

        self.monitoringP = YES;
        NSMutableAttributedString *refreshString =
            [[NSMutableAttributedString alloc] initWithString:@"Pull To Reconnect"];
        [refreshString addAttributes:@{ NSForegroundColorAttributeName: [UIColor grayColor] }
                               range:NSMakeRange(0, refreshString.length)];
        self.refreshControl.attributedTitle = refreshString;
        [self deleteAllTableData:NO];
        [self notifyUser:self.taasName withTitle:kConnected];
        self.entities = nil;
        self.groups = nil;
        self.tasks = nil;
        [self.service listDevices];

        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        if (appDelegate.documentScripts != nil) {
            NSString *scriptPath = [[appDelegate.documentScripts stringByAppendingPathComponent:self.taasName]
                                        stringByAppendingPathExtension:@"json"];
            NSData *data = [[NSFileManager defaultManager] fileExistsAtPath:scriptPath]
                               ? [[NSFileManager defaultManager] contentsAtPath:scriptPath] : nil;
            NSError *error = nil;
            NSDictionary *scripts = (data != nil) ? [NSJSONSerialization JSONObjectWithData:data
                                                                                    options:kNilOptions
                                                                                      error:&error]
                                                  : nil;
            if (scripts != nil) {
                [scripts enumerateKeysAndObjectsUsingBlock:^(NSString *property, id values, BOOL *stop) {
                    if ((![property isEqualToString:@"commands"]) || (![values isKindOfClass:[NSArray class]])) return;
                    [values enumerateObjectsUsingBlock:^(NSDictionary *value, NSUInteger idx, BOOL *stop) {
                        [self pushDataDictionary:@{ kDataEntry  : [value objectForKey:@"name"]
                                                  , kScriptInfo : value
                                                  }
                                       ontoTable:self.tableTasksData
                                     withOptions:kPushNone];

                    }];

                    [self pushDataDictionary:nil
                                   ontoTable:self.tableTasksData
                                 withOptions:(kPushRefresh | kPushInvert)];
                }];
            }
        }

        UIApplication *application = [UIApplication sharedApplication];
        application.applicationIconBadgeNumber = 0;

        NSDictionary *result = [dictionary objectForKey:@"result"];
        if (result != nil) {
            NSDictionary *client = [dictionary objectForKey:@"client"];
            if (client != nil) {
                [self notifyUser:[NSString stringWithFormat:@"%@: authenticated", self.taasName]
                       withTitle:kConnected];
            }
            return;
        }
    }
    if ((dictionary == nil) || ([dictionary objectForKey:@"notice"] != nil)) return;

    [dictionary enumerateKeysAndObjectsUsingBlock:^(id category, id values, BOOL *stop) {
        if (([category isEqual:@"notice"]) && ([values isKindOfClass:[NSDictionary class]])) {
            self.permissions = [values objectForKey:@"permissions"];
            DDLogInfo(@"permissions: %@", self.permissions);

            NSString *level =   [self.permissions containsObject:@"manage"]  ? @"manager"
                              : [self.permissions containsObject:@"write"]   ? @"resident"
                              : [self.permissions containsObject:@"perform"] ? @"guest" : @"monitor";
            [self notifyUser:[NSString stringWithFormat:@"%@: %@", self.taasName, level]
                   withTitle:kConnected];
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
            if ((date.length == 0) || (message.length == 0)) return;
            NSString *meta = ([entry objectForKey:@"meta"] != [NSNull null])
                                 ? [entry objectForKey:@"meta"] : @" ";
            NSString *data = [[TAASPrettyPrinter singleton] valuesPP:meta];
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

- (void)didReceiveResult:(NSDictionary *)dictionary {
    if (dictionary == nil) return;

    NSDictionary *result = [dictionary objectForKey:@"result"];
    if (self.entities != nil) {
        if (self.tasks != nil) [self didReceiveResponse:dictionary]; else [self didReceiveActivities:result];
        return;
    }

    NSDictionary *oops;
&& (self.tasks != nil)) {    if ((oops = [dictionary objectForKey:@"error"]) != nil) {
        NSString *diagnostic = [oops objectForKey:@"diagnostic"];
        if (diagnostic == nil) diagnostic = @"invalid response";
        [self notifyUser:diagnostic withTitle:kError];
        return;
    }
    self.entities = [[NSMutableDictionary alloc] init];
    [self.service listActivities];

    [result enumerateKeysAndObjectsUsingBlock:^(id whatami, id values, BOOL *stop) {
        if ([whatami isEqual:@"actors"]) return;

        NSRange range = [whatami rangeOfString:@"/device/" options:NSAnchoredSearch];
        if (range.location == NSNotFound) {
            range = [whatami rangeOfString:@"/place" options:NSAnchoredSearch];
        }
        if (range.location == NSNotFound) {
          if ([whatami isEqualToString:@"/group"]) self.groups = [values mutableCopy];
          return;
        }

        [values enumerateKeysAndObjectsUsingBlock:^(id whoami, id value, BOOL *stop) {
            NSMutableDictionary *entity = [NSMutableDictionary dictionaryWithDictionary:value];
            [entity setObject:whoami forKey:kWhoAmI];
            [entity setObject:whatami forKey:kWhatAmI];

            [self.entities setObject:entity forKey:whoami];
        }];
    }];

    if (self.groups != nil) {
        [self.groups enumerateKeysAndObjectsUsingBlock:^(id whoami, NSMutableDictionary *group, BOOL *stop) {
            NSArray *members = [group valueForKey:@"members"];
            if ((members == nil) || (members.count < 1)) return;

            group = [group mutableCopy];
            [group setObject:[self recurseMembers:members alreadySeen:[NSMutableArray arrayWithCapacity:self.groups.count]]
                                           forKey:@"members"];
            [self.groups setObject:group forKey:whoami];
        }];
    }

    [result enumerateKeysAndObjectsUsingBlock:^(id whatami, id values, BOOL *stop) {
        if ([whatami isEqual:@"actors"]) return;

        NSRange range = [whatami rangeOfString:@"/device/" options:NSAnchoredSearch];
        if (range.location == NSNotFound) {
            range = [whatami rangeOfString:@"/place" options:NSAnchoredSearch];
        }
        if (range.location == NSNotFound) return;

        [values enumerateKeysAndObjectsUsingBlock:^(id whoami, id value, BOOL *stop) {
            NSDictionary *entity = (whoami != nil) ? [self.entities objectForKey:whoami] : nil;
            [self updateDevice:entity];
        }];
    }];
    [self pushDataDictionary:nil ontoTable:self.tableDevicesData withOptions:(kPushRefresh | kPushSort)];

    [self processTasksData];
}

- (void)didReceiveActivities:(NSDictionary *)result {
    self.tasks = [result objectForKey:@"tasks"];
    if (self.tasks != nil) [self processTasksData];
}

// we do ALL this just to get a pretty icon on the "Tasks" tab...
- (void)processTasksData {
    [self.tableTasksData enumerateObjectsUsingBlock:^(NSDictionary *value, NSUInteger idx, BOOL *stop) {
        NSMutableDictionary *entry = [value mutableCopy];
        NSString *ikon = [entry objectForKey:kIkonEntry];
        if (ikon != nil) return;

        NSDictionary *script = [value objectForKey:kScriptInfo];
        NSDictionary *action = [script objectForKey:@"perform"];
        if (action == nil) action = [script objectForKey:@"report"];
        if (action == nil) return;

        NSString *entity = [action objectForKey:@"entity"];
        if ([entity isEqualToString:@"actor"]) {
            NSString *prefix = [action objectForKey:@"prefix"];
            if (prefix == nil) return;

            NSRange range = [prefix rangeOfString:@"/device/" options:NSAnchoredSearch];
            if (range.location == NSNotFound) return;

            NSArray *components = [prefix componentsSeparatedByString:@"/"];
            switch (components.count) {
                case 2:
                case 3: {
                    NSDictionary *pairs = @{ @"climate"   : @"climate-generic"
                                           , @"gateway"   : @"gateway-cloud"
                                           , @"indicator" : @"indicator-gauge"
                                           , @"lighting"  : @"lighting-bulb"
                                           , @"media"     : @"media-video"
                                           , @"motive"    : @"motive-drone"
                                           , @"presence"  : @"presence-fob"
                                           , @"sensor"    : @"sensor-generic"
                                           , @"switch"    : @"switch-meter"
                                           , @"wearable"  : @"wearable-watch"
                                           };
                    ikon = [pairs objectForKey:components[2]];
                    if (ikon == nil) return;
                    [entry setObject:ikon forKey:kIkonEntry];
                    break;
                }

                case 5:
                    [entry setObject:[NSString stringWithFormat:@"%@-%@", components[2], components[4]] forKey:kIkonEntry];
                    break;

                default:
                    return;
            }

            [self.tableTasksData replaceObjectAtIndex:idx withObject:entry];
            return;
        }

        NSNumber *entityID = [action objectForKey:@"id"];
        if ((entityID == nil) || ([entityID integerValue] < 0)) return;

        NSArray *members;
        NSDictionary *group, *task;
        NSRange range;
        if ([entity isEqualToString:@"group"]) {
            group = (self.groups != nil) ? [self.groups objectForKey:[NSString stringWithFormat:@"group/%@", entityID]] : nil;
            members = (group != nil) ? [group valueForKey:@"members"] : nil;
            if ((members == nil) || (members.count < 1)) return;

            entity = [group valueForKey:@"type"];
            if ([entity isEqualToString:@"device"]) {
                range = [members[0] rangeOfString:@"device/" options:NSAnchoredSearch];
                if (range.location == NSNotFound) return;
                entityID = [NSNumber numberWithInteger:[[members[0] substringFromIndex:7] integerValue]];
            } else if ([entity isEqualToString:@"task"]) {
                range = [members[0] rangeOfString:@"task/" options:NSAnchoredSearch];
                if (range.location == NSNotFound) return;
                entityID = [NSNumber numberWithInteger:[[members[0] substringFromIndex:6] integerValue]];
            } else {
                return;
            }
        }

        if ([entity isEqualToString:@"device"]) {
            [entry setObject:[NSString stringWithFormat:@"device/%@", entityID] forKey:kWhoEntry];
        } else if ([entity isEqualToString:@"task"]) {
            task = (self.tasks != nil) ? [self.tasks objectForKey:[NSString stringWithFormat:@"task/%@", entityID]] : nil;
            NSString *actor = (task != nil) ? [task objectForKey:@"actor"] : nil;
            if (actor == nil) return;

            range = [actor rangeOfString:@"device/" options:NSAnchoredSearch];
            if (range.location != NSNotFound) {
                entityID = [NSNumber numberWithInteger:[[actor substringFromIndex:7] integerValue]];
                [entry setObject:[NSString stringWithFormat:@"device/%@", entityID] forKey:kWhoEntry];
            } else {
                range = [actor rangeOfString:@"group/" options:NSAnchoredSearch];
                if (range.location == NSNotFound) return;

                entityID = [NSNumber numberWithInteger:[[actor substringFromIndex:6] integerValue]];
                group = (self.groups != nil)
                            ? [self.groups objectForKey:[NSString stringWithFormat:@"group/%@", entityID]]
                            : nil;
                members = (group != nil) ? [group valueForKey:@"members"] : nil;
                if ((members == nil) || (members.count < 1)) return;

                entity = [group valueForKey:@"type"];
                if (![entity isEqualToString:@"device"]) return;

                range = [members[0] rangeOfString:@"device/" options:NSAnchoredSearch];
                if (range.location == NSNotFound) return;
                entityID = [NSNumber numberWithInteger:[[members[0] substringFromIndex:7] integerValue]];
                [entry setObject:[NSString stringWithFormat:@"device/%@", entityID] forKey:kWhoEntry];
            }
        }

        [self.tableTasksData replaceObjectAtIndex:idx withObject:entry];
    }];
}

- (NSArray *)recurseMembers:(NSArray *)members
                alreadySeen:(NSMutableArray *)groups {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:members.count];

    [members enumerateObjectsUsingBlock:^(NSString *member, NSUInteger idx, BOOL *stop) {
        NSRange range = [member rangeOfString:@"group/" options:NSAnchoredSearch];
        if (range.location == NSNotFound) {
            [array addObject:member];
            return;
        }

        if ([groups containsObject:member]) return;
        [groups addObject:member];

        NSMutableDictionary *group = [self.groups objectForKey:member];
        if (group == nil) return;

        NSArray *children = [group valueForKey:@"members"];
        if ((children == nil) || (children.count < 1)) return;

        [array addObjectsFromArray:[self recurseMembers:children alreadySeen:groups]];
    }];

    return array;
}

- (void)updateDevice:(NSDictionary *)entity {
    NSString *whoami = [entity objectForKey:kWhoAmI];
    NSRange range = [whoami rangeOfString:@"device/" options:NSAnchoredSearch];
    if (range.location == NSNotFound) {
        range = [whoami rangeOfString:@"place/" options:NSAnchoredSearch];
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

    [info enumerateKeysAndObjectsUsingBlock:^(id key, NSString *value, BOOL *stop) {
        if (![key isEqualToString:@"displayUnits"]) return;
        self.customaryP = [value isEqualToString:@"customary"];
        *stop = YES;
    }];

    NSString *data = [[TAASPrettyPrinter singleton] infoPP:info];
    NSString *whatami = [entity objectForKey:kWhatAmI];
    range = [whatami rangeOfString:@"/device/gateway/" options:NSAnchoredSearch];
    if ((range.location != NSNotFound) || (data == nil)) data = @" ";

    NSString *name = [entity objectForKey:@"name"];
    if (name == nil) name = whoami;
    name = [NSString stringWithFormat:@"%@:", name];
    char keystring[BUFSIZ];
    snprintf(keystring, sizeof keystring, "%s", (const char *)[name UTF8String]);
    NSString *output = [NSString stringWithFormat:@"%-*s %@\n%@", kKeyLength, keystring,
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

- (void)didReceiveResponse:(NSDictionary *)dictionary {
    NSDictionary *oops;

    if ((dictionary != nil) && ((oops = [dictionary objectForKey:@"error"]) != nil)) {
        NSString *diagnostic = [oops objectForKey:@"diagnostic"];
        if (diagnostic == nil) diagnostic = @"invalid response";
        [self notifyUser:diagnostic withTitle:kError];
    }
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

    [self notifyUser:[NSString stringWithFormat:@"found %@", [self serverName:info]]
           withTitle:kConnecting];
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
        addresses = [NSMutableArray arrayWithCapacity:count];

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

- (NSString *)serverName:(NSDictionary *)info {
    NSDictionary *txt = [info objectForKey:kTXT];
    NSString *name = (txt != nil) ? [txt objectForKey:kName] : nil;
    if (name == nil) name = [self hostName:info];
    NSRange range = [name rangeOfString:@"."];
    if (range.location != NSNotFound) name = [name substringToIndex:range.location];

    return name;
}

- (NSString *)hostName:(NSDictionary *)info {
    NSString *name = [info objectForKey:kHostName];
    NSRange range = [name rangeOfString:@"." options:(NSBackwardsSearch | NSAnchoredSearch)];
    if (range.location != NSNotFound) name = [name substringToIndex:range.location];
    range = [name rangeOfString:@".local" options:(NSBackwardsSearch | NSAnchoredSearch)];
    if (range.location != NSNotFound) name = [name substringToIndex:range.location];

    return name;
}

- (NSString *)issuer:(NSDictionary *)info {
    NSString *authURI = [info objectForKey:kAuthURL];
    NSURL *authURL = (authURI.length > 0) ? [NSURL URLWithString:authURI] : nil;
    if (authURL == nil) return nil;

    NSArray *array = [authURI componentsSeparatedByString:@"/"];
    if (array.count < 4) return nil;
    NSString *issuer = [[[array objectAtIndex:(array.count - 4)] componentsSeparatedByString:@":"]
                            objectAtIndex:0];
    if (issuer.length == 0) return nil;

    return issuer;
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
                                                    cancelButtonTitle:nil
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:nil];

    FXKeychain *keyChain = [FXKeychain defaultKeychain];
    NSArray *allStewards = [keyChain objectForKey:kAllStewards];
    self.actionSheetChoices = nil;
    if ((allStewards != nil) && (allStewards.count > 1)) {
        allStewards = [allStewards sortedArrayUsingComparator:^(NSString *obj1, NSString *obj2) {
            NSDictionary *info1 = [keyChain objectForKey:obj1];
            NSString *name1 = (info1 != nil) ? [self serverName:info1] : nil;

            NSDictionary *info2 = [keyChain objectForKey:obj2];
            NSString *name2 = (info2 != nil) ? [self serverName:info2] : nil;

            if (name1 != nil) return ((name2 != nil) ? [name1 compare:name2] : NSOrderedDescending);
            return ((name2 != nil) ? NSOrderedAscending : NSOrderedSame);
        }];

        self.actionSheetChoices = [NSMutableDictionary dictionaryWithCapacity:allStewards.count];
        [allStewards enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
            NSDictionary *info = [keyChain objectForKey:value];
            if (info == nil) return;

            NSInteger offset = [actionSheet addButtonWithTitle:
                                                [NSString stringWithFormat:@"Connect to %@",
                                                              [self serverName:info]]];

            [self.actionSheetChoices setObject:info forKey:[NSNumber numberWithInteger:offset]];
        }];
    }
    [actionSheet addButtonWithTitle:@"Scan QR code"];
    actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle:@"Clear History"];
    actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:@"Cancel"];

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
    if (actionSheet.cancelButtonIndex == buttonIndex) return;

    NSDictionary *info;
    NSNumber *index;
    switch (actionSheet.tag) {
        // root action sheet
        case 0:
          if (actionSheet.destructiveButtonIndex == buttonIndex) {
              [self confirmActionSheet:nil];
              break;
          }
          index = [NSNumber numberWithInteger:buttonIndex];
          info = (self.actionSheetChoices != nil) ? [self.actionSheetChoices objectForKey:index] : nil;
          if (info != nil) [self connectToSteward:info localP:NO]; else [self scanQRcode:nil];
          break;

        // confirm deletion action sheet
        case 1:
            [self deleteAllTableData:YES];
            break;

        default:
            break;
    }
}


#pragma mark - tableView dataSource

- (void)deleteAllTableData:(BOOL)forceP {
    if (forceP) {
        [self.tableConsoleData removeAllObjects];
        if (self.tableConsoleData == self.currentDataTable) [self.tableView reloadData];
        return;
    }

    [self.tableConsoleData enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
        if ([value objectForKey:kWhoEntry] == nil) return;

        *stop = YES;
        NSUInteger length = self.tableConsoleData.count - idx;
        [self.tableConsoleData removeObjectsInRange:NSMakeRange(idx, length - 1)];
    }];
    [self.tableDevicesData removeAllObjects];
    [self.tableTasksData removeAllObjects];
    [self.tableView reloadData];
}

- (void)pushDataDictionary:(NSDictionary *)dictionary
                 ontoTable:(NSMutableArray *) tableArray
               withOptions:(unsigned long)options {
  NSMutableArray *array;

    if (dictionary != nil) [tableArray insertObject:dictionary atIndex:0];

    if (tableArray.count > 1) {
        if (options & kPushSort) {
            array = [NSMutableArray arrayWithArray:[tableArray sortedArrayUsingComparator:^(NSDictionary *obj1,
                                                                                            NSDictionary *obj2) {
                NSRange range = [[obj1 objectForKey:kWhoEntry] rangeOfString:@"place/"
                                                                     options:NSAnchoredSearch];
                BOOL placeP = range.location != NSNotFound;
                range = [[obj2 objectForKey:kWhoEntry] rangeOfString:@"place/" options:NSAnchoredSearch];
                if (placeP) {
                    if (range.location == NSNotFound) return NSOrderedAscending;
                } else if (range.location != NSNotFound) return NSOrderedDescending;

                return [[obj2 objectForKey:kWhenEntry] compare:[obj1 objectForKey:kWhenEntry]];
            }]];
        } else if (options & kPushInvert) {
            array = [NSMutableArray arrayWithArray:tableArray];
            NSUInteger count = tableArray.count - 1;
            [tableArray enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
                [array replaceObjectAtIndex:idx withObject:[tableArray objectAtIndex:(count - idx)]];
          }];
        }

        if (options & (kPushSort | kPushInvert)) {
            BOOL updateCurrentTable = (self.currentDataTable == tableArray);
                 if (self.tableConsoleData == tableArray) self.tableConsoleData = array;
            else if (self.tableDevicesData == tableArray) self.tableDevicesData = array;
            else                                          self.tableTasksData   = array;
            if (updateCurrentTable) self.currentDataTable = array;
            tableArray = array;
        }
    }

    if ((options & kPushRefresh) && (self.currentDataTable == tableArray)) [self.tableView reloadData];
}

-    (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat rowHeight = 54.0f;
    CGFloat fontSize = 13.0f;
    NSDictionary *tableEntry = [self.currentDataTable objectAtIndex:indexPath.row];

    UIFont *font = [UIFont fontWithName:@"Menlo-Regular" size:fontSize];
    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObject:font
                                                                forKey:NSFontAttributeName];
    NSAttributedString *attrString1 =
        [[NSAttributedString alloc] initWithString:[tableEntry objectForKey:kDataEntry]
                                        attributes:attrsDictionary];
    CGFloat label1Height =
        [attrString1 boundingRectWithSize:CGSizeMake([tableView frame].size.width - 65, 450)
                                  options:NSStringDrawingUsesLineFragmentOrigin
                                  context:nil].size.height;
    return fmax(rowHeight, label1Height + fontSize);
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

    NSString *whoami = [tableEntry objectForKey:kWhoEntry];
    NSDictionary *entity = (whoami != nil) ? [self.entities objectForKey:whoami] : nil;
    NSString *ikon = (entity != nil) ? [entity objectForKey:kIkonEntry] : [tableEntry objectForKey:kIkonEntry];
    NSString *imageName = (ikon != nil) ? ikon : @"place-home";
    if (ikon == nil) {
        NSString *whatami = (entity != nil) ? [entity objectForKey:kWhatAmI] : nil;
        NSArray *components = (whatami != nil) ? [whatami componentsSeparatedByString:@"/"] : nil;
        if ((components != nil) && (components.count == 5)) {
            imageName = [NSString stringWithFormat:@"%@-%@", components[2], components[4]];
        }
    }
    cell.icon.image = [UIImage imageNamed:imageName];

    return cell;
}

-       (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *tableEntry = [self.currentDataTable objectAtIndex:indexPath.row];
    NSDictionary *script = [tableEntry objectForKey:kScriptInfo];

    if (script != nil) [self scripter:script];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)scripter:(NSDictionary *)script {
    NSDictionary *action = [script objectForKey:@"perform"];
    if (action == nil) return;

    NSString *path = nil;
    NSString *entity = [action objectForKey:@"entity"];
    if ([entity isEqualToString:@"actor"]) {
        NSString *prefix = [action objectForKey:@"prefix"];
        if (prefix == nil) return;
        path = [NSString stringWithFormat:@"/api/v1/%@/perform%@", entity, prefix];

    } else {
        NSNumber *entityID = [action objectForKey:@"id"];
        if ((entityID == nil) || ([entityID integerValue] < 0)) return;
        path = [NSString stringWithFormat:@"/api/v1/%@/perform/%@", entity, entityID];
    }
    NSUInteger requestID = [Client sharedClient].requestCounter;
    [Client sharedClient].requestCounter = requestID + 1;
    NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
    [request addEntriesFromDictionary:@{ @"requestID" : [NSString stringWithFormat:@"%lu", requestID]
                                       , @"path"      : path
                                       }];
    NSString *perform = [action objectForKey:@"perform"];
    if (perform != nil) [request setObject:perform forKey:@"perform"];
    NSString *parameter = [action objectForKey:@"parameter"];
    if (parameter != nil) [request setObject:parameter forKey:@"parameter"];

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:request options:0 error:&error];
    if (error != nil) {
        [self notifyUser:@"encoding error" withTitle:kError];
        return;
    }

    [self.service roundTrip:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
}


// UIRefreshControl event processing

- (void)refreshPulled {
    [self.refreshControl endRefreshing];

    [self resetSteward:NO];
    [self setTimeout];
    [self deleteAllTableData:YES];
    [self notifyUser:(self.monitoringP ? @"reconnecting..." : @"retrying...")
           withTitle:kDiscovery];
}

@end
