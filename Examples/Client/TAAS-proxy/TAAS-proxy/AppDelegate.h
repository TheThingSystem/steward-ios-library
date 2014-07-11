//
//  AppDelegate.h
//  TAAS-proxy
//
//  TOTP example originally created by Alasdair Allan on 29/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import "RNPinnedCertValidator.h"
#import "RootController.h"

@class HTTPServer;


@interface AppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate>

#define kAttention    @"Attention"
#define kConnected    @"Connected"
#define kConnecting   @"Connecting"
#define kDiscovery    @"Discovery"
#define kError        @"Error"


@property (strong, nonatomic) UIWindow                  *window;
@property (strong, nonatomic) RootController            *rootController;
@property (strong, nonatomic) AVAudioSession            *audioSession;
@property (strong, nonatomic) AVSpeechSynthesizer       *speechSynthesizer;
@property (strong, nonatomic) RNPinnedCertValidator     *pinnedCertValidator;


- (void)backgroundNotify:(NSString *)message
                andTitle:(NSString *)title;

@end
