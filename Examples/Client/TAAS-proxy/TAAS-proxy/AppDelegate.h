//
//  AppDelegate.h
//  TAAS-proxy
//
//  TOTP example originally created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "RootController.h"

@class HTTPServer;


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow                  *window;
@property (strong, nonatomic) RootController            *rootController;
@property (strong, nonatomic) AVSpeechSynthesizer       *speechSynthesizer;


- (void)backgroundNotify:(NSString *)message
                andTitle:(NSString *)title;

@end
