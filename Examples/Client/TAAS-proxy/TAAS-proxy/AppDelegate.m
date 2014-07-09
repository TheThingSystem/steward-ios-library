//
//  AppDelegate.m
//  TAAS-proxy
//
//  TOTP example originally created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "AppDelegate.h"
#import "RootController.h"
#import "HTTPServer.h"
#import "TAASConnection.h"
#import "DDLog.h"
#import "DDFileLogger.h"
#import "DDTTYLogger.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface AppDelegate ()

@property (        nonatomic) BOOL                       launchedP;
@property (        nonatomic) BOOL                       backgroundSupported;
@property (        nonatomic) UIBackgroundTaskIdentifier backgroundTaskID;
@property (        nonatomic) UIBackgroundTaskIdentifier notifyTaskID;
@property (strong, nonatomic) HTTPServer                *httpServer;
@property (strong, nonatomic) NSMutableArray            *lastNotifications;
@property (strong, nonatomic) CLLocationManager         *locationManager;

@end


@implementation AppDelegate

#define kDocumentCerts   @"Certs"
#define kDocumentLogs    @"Logs"
#define kDocumentRoot    @"Web"


-           (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSError *error;

    if (self.launchedP) {
        [self reportLaunch:application withOptions:launchOptions];

        if ([launchOptions objectForKey:UIApplicationLaunchOptionsLocationKey] == nil) return YES;

        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        [self.locationManager startMonitoringSignificantLocationChanges];
        return YES;
    }

    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    NSString *documentLogs = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        documentLogs = [[paths objectAtIndex:0] stringByAppendingPathComponent:kDocumentLogs];
    }
    if ((documentLogs != nil) && (![[NSFileManager defaultManager] fileExistsAtPath:documentLogs])) {
        if (![[NSFileManager defaultManager]
                   createDirectoryAtPath:documentLogs
             withIntermediateDirectories:YES
                              attributes:nil
                                   error:&error]) {
          DDLogError(@"create %@: %@", documentLogs, error);
          documentLogs = nil;
        }
    }
    if (documentLogs != nil) {
        DDLogFileManagerDefault *logFileManager = [[DDLogFileManagerDefault alloc]
                                                        initWithLogsDirectory:documentLogs];
        [DDLog addLogger:[[DDFileLogger alloc] initWithLogFileManager:logFileManager]];
    }

    DDLogVerbose(@"begin");

    NSString *documentRoot = nil;
    if (paths.count > 0) {
        documentRoot = [[paths objectAtIndex:0] stringByAppendingPathComponent:kDocumentRoot];
    }
    if ((documentRoot != nil) && (![[NSFileManager defaultManager] fileExistsAtPath:documentRoot])) {
        NSString *src = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:kDocumentRoot];
        error = nil;
        if (![[NSFileManager defaultManager]
                   copyItemAtPath:src
                           toPath:documentRoot
                            error:&error]) {
            DDLogError(@"copy %@ to %@: %@", documentRoot, src, error);
        }
    }

    NSString *documentCerts = nil;
    documentCerts = nil;
    self.pinnedCertValidator = nil;
    if (paths.count > 0) {
        documentCerts = [[paths objectAtIndex:0] stringByAppendingPathComponent:kDocumentCerts];
    }
    if ((documentCerts != nil)
            && (![[NSFileManager defaultManager] fileExistsAtPath:documentCerts])) {
        error = nil;
        if (![[NSFileManager defaultManager]
                   createDirectoryAtPath:documentCerts
             withIntermediateDirectories:YES
                              attributes:nil
                                   error:&error]) {
          DDLogError(@"create %@: %@", documentCerts, error);
          documentCerts = nil;
        }
    }
    if (documentCerts != nil) {
        error = nil;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentCerts
                                                                             error:&error];
        NSMutableArray *trustedCertificates = [NSMutableArray array];
        if (files != nil) {
            [files enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL *stop) {
                NSError *error = nil;

                NSString *path = [documentCerts stringByAppendingPathComponent:name];
                BOOL isDir = NO;
                if ((![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
                        || (isDir)) return;

// openssl x509 -outform der -in certificate.crt -out certificate.cer
                NSRange range = [name rangeOfString:@".cer"
                                            options:(NSBackwardsSearch | NSAnchoredSearch)];
                if (range.location == NSNotFound) return;

                NSData *data = [NSData dataWithContentsOfFile:path
                                                      options:0
                                                        error:&error];
                if (data == nil) {
                    DDLogError(@"read %@: %@", path, error);
                    return;
                }
                SecCertificateRef certificate =
                    SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(data));
                [trustedCertificates addObject:CFBridgingRelease(certificate)];
                DDLogVerbose(@"pin cert %@", name);
            }];
            if (trustedCertificates.count > 0) {
                self.pinnedCertValidator = [[RNPinnedCertValidator alloc] init];
                self.pinnedCertValidator.trustedCertificates = trustedCertificates;
            }
        } else {
          DDLogError(@"list %@: %@", documentCerts, error);
          documentCerts = nil;
        }
    }

    [self reportLaunch:application withOptions:launchOptions];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.rootController = [[RootController alloc] initWithNibName:@"RootController" bundle:nil];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = self.rootController;

    self.httpServer = [[HTTPServer alloc] init];
    [self.httpServer setConnectionClass:[TAASConnection class]];
    [self.httpServer setInterface:@"lo0"];
    [self.httpServer setPort:8884];
    if (documentRoot != nil) [self.httpServer setDocumentRoot:documentRoot];

    error = nil;
    if (![self.httpServer start:&error]) {
        DDLogError(@"error starting HTTP Server: %@", error);
        self.httpServer = nil;
    }

    self.audioSession = [AVAudioSession sharedInstance];

    error = nil;
    [self.audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error != nil) DDLogError(@"error setting audio session category to playback: %@", error);

    error = nil;
    [self.audioSession setActive:YES error:&error];
    if (error!= nil) {
        DDLogError(@"error setting audio session active: %@", error);
        self.audioSession = nil;
    }

    self.speechSynthesizer = [[AVSpeechSynthesizer alloc] init];

    self.backgroundSupported = NO;
    UIDevice *device = [UIDevice currentDevice];
    if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
      self.backgroundSupported = device.multitaskingSupported;
    }
    if (!self.backgroundSupported) DDLogError(@"background processing not supported");
    NSArray *backgroundModes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIBackgroundModes"];
    if ([backgroundModes indexOfObject:@"voip"] == NSNotFound) self.backgroundSupported = NO;
    self.backgroundTaskID = UIBackgroundTaskInvalid;
    self.notifyTaskID = UIBackgroundTaskInvalid;

    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        [self.locationManager startMonitoringSignificantLocationChanges];
    } else {
        DDLogError(@"signfication location monitoring not supported");
    }

    [self.window makeKeyAndVisible];

    if (application.applicationState == UIApplicationStateBackground) {
        [self applicationDidEnterBackground:application];
    }

    self.launchedP = YES;
    return YES;
}

- (void)reportLaunch:(UIApplication *)application
         withOptions:(NSDictionary *)launchOptions {
    int state = (int) application.applicationState;
    NSArray *choices = @[ @"active", @"inactive", @"background" ];
    DDLogVerbose(@"didFinishLaunchingWithOptions: %@ options=%@",
                 (0 <= state) && (state < choices.count)
                     ? [choices objectAtIndex:state]
                     : [NSString stringWithFormat:@"%d (unknown state)", state],
                   launchOptions);
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    DDLogVerbose(@"applicationWillEnterForeground");

    application.applicationIconBadgeNumber = 0;
    [self keepAlive:application onoff:NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    DDLogVerbose(@"applicationDidBecomeActive");
    self.lastNotifications = nil;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    DDLogVerbose(@"applicationDidResignActive");

    application.applicationIconBadgeNumber = 0;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    int status = (int) application.backgroundRefreshStatus;
    NSArray *choices = @[ @"restricted", @"denied", @"available" ];

    DDLogVerbose(@"applicationDidEnterBackground: %@",
                 (0 <= status) && (status < choices.count)
                     ? [choices objectAtIndex:status]
                     : [NSString stringWithFormat:@"%d (unknown status)", status]);
    [self keepAlive:application onoff:YES];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    DDLogVerbose(@"applicationWillTerminate");

    if (self.httpServer != nil) [self.httpServer stop:NO];

    if (self.notifyTaskID != UIBackgroundTaskInvalid) {
        [application endBackgroundTask:self.notifyTaskID];
        self.notifyTaskID = UIBackgroundTaskInvalid;
    }

// must do immediately, not put on the main queue...
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    if (localNotification == nil) return;

    localNotification.alertBody = @"Terminated. Tap to restart.";
    localNotification.alertAction = kAttention;
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    localNotification.applicationIconBadgeNumber = 1;
    [application presentLocalNotificationNow:localNotification];
}

-         (void)application:(UIApplication *)application
didReceiveLocalNotification:(UILocalNotification *)notification {
    DDLogVerbose(@"didReceiveLocalNotication");

    application.applicationIconBadgeNumber = 0;
}


#pragma mark - keep-alive

- (void)keepAlive:(UIApplication *)application
            onoff:(BOOL)onoff {
    if (!self.backgroundSupported) return;

    DDLogVerbose(@"keepAlive onoff=%@", onoff ? @"YES" : @"NO");

    if (self.backgroundTaskID != UIBackgroundTaskInvalid) {
        if (onoff) return;

        [application endBackgroundTask:self.backgroundTaskID];
        self.backgroundTaskID = UIBackgroundTaskInvalid;
    }
    if (!onoff) return;

    self.backgroundTaskID = [application beginBackgroundTaskWithExpirationHandler:^{
        [self keepAlive:application onoff:YES];
    }];
    if (self.backgroundTaskID == UIBackgroundTaskInvalid) {
        DDLogError(@"unable to create background task");
        return;
    }

    DDLogVerbose(@"remaining background time: %f", application.backgroundTimeRemaining);
}


#pragma mark - notifications

- (void)backgroundNotify:(NSString *)message
                andTitle:(NSString *)title {
    DDLogVerbose(@"backgroundNotify: %@ - %@ tasking=%@", title, message,
                 (self.notifyTaskID != UIBackgroundTaskInvalid) ? @"YES" : @"NO");
    if (self.notifyTaskID != UIBackgroundTaskInvalid) return;

    // suppress duplicate runs of notifications (they often travel in pairs!)
    if (self.lastNotifications == nil) {
        self.lastNotifications = [NSMutableArray arrayWithCapacity:4];
    }
    BOOL containsP = [self.lastNotifications containsObject:message];
    [self.lastNotifications insertObject:message atIndex:0];
    if (self.lastNotifications.count > 3) [self.lastNotifications removeLastObject];
    if (containsP) return;

    UIApplication *application = [UIApplication sharedApplication];
    self.notifyTaskID = [application beginBackgroundTaskWithExpirationHandler: ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [application endBackgroundTask:self.notifyTaskID];
            self.notifyTaskID = UIBackgroundTaskInvalid;
        });
    }];

    dispatch_async(dispatch_get_main_queue(), ^{
        while ([application backgroundTimeRemaining] > 1.0) {
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            if (localNotification == nil) break;

            localNotification.alertBody = message;
            localNotification.alertAction = title;
            localNotification.soundName = UILocalNotificationDefaultSoundName;
            localNotification.applicationIconBadgeNumber = 1;
            [application presentLocalNotificationNow:localNotification];
            break;
        }

        [application endBackgroundTask:self.notifyTaskID];
        self.notifyTaskID = UIBackgroundTaskInvalid;
    });
}


#pragma mark - CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    DDLogVerbose(@"locations: %@", locations);
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    DDLogError(@"location manager error: %@", error);
}

@end
