//
//  AppDelegate.m
//  TAAS-proxy
//
//  TOTP example created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "AppDelegate.h"
#import "RootController.h"
#import "Client.h"
#import "HTTPServer.h"
#import "TAASConnection.h"
#import "DDLog.h"
#import "DDTTYLogger.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [DDLog addLogger:[DDTTYLogger sharedInstance]];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.rootController = [[RootController alloc] initWithNibName:@"RootController" bundle:nil];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = self.rootController;

    Client *client = [Client sharedClient];
    DDLogVerbose(@"Client Library v%@", [Client version]);
    client.debug = YES;
    client.delegate = self.rootController;

    self.httpServer = [[HTTPServer alloc] init];
    [self.httpServer setConnectionClass:[TAASConnection class]];
    [self.httpServer setPort:8884];
    NSString *documentRoot = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([paths count] > 0) documentRoot = [paths objectAtIndex:0];
    DDLogVerbose(@"Document Root %@", documentRoot);
    [self.httpServer setDocumentRoot:documentRoot];

    NSError *error = nil;
    if (![self.httpServer start:&error]) {
      DDLogError(@"Error starting HTTP Server: %@", error);
      self.httpServer = nil;
    }

    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {

}

- (void)applicationDidEnterBackground:(UIApplication *)application {

}

- (void)applicationWillEnterForeground:(UIApplication *)application {

}

- (void)applicationDidBecomeActive:(UIApplication *)application {

}

- (void)applicationWillTerminate:(UIApplication *)application {

}

@end
