//
//  AppDelegate.h
//  TAAS-proxy
//
//  TOTP example created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RootController;
@class HTTPServer;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow          *window;
@property (strong, nonatomic) RootController    *rootController;
@property (strong, nonatomic) HTTPServer        *httpServer;

@end
