//
//  AppDelegate.m
//  Accelerometer
//
//  Created by Alasdair Allan on 08/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "AppDelegate.h"
#import "RootController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.rootController = [[RootController alloc] initWithNibName:@"RootController" bundle:nil];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = self.rootController;
        
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