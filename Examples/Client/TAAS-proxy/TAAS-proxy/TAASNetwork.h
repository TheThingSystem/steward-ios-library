//
//  TAASNetwork.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 8/11/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface TAASNetwork : NSObject

+ (TAASNetwork *)singleton;

- (NSDictionary *)routingInfo;

@end
