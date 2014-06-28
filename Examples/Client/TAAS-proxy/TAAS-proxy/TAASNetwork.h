//
//  TAASNetwork.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 6/28/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FXReachability.h"


@interface TAASNetwork : NSObject
@property (        nonatomic) FXReachabilityStatus       fxReachabilityStatus;

+ (TAASNetwork *)sharedInstance;

@end
