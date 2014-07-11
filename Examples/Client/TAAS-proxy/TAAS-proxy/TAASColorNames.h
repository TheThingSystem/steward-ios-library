//
//  TAASColorNames.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 7/8/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TAASColorNames : NSObject

@property (strong, nonatomic) NSDictionary    *colors;


+ (TAASColorNames *)singleton;
- (NSString *)rgb2string:(NSArray *)rgb;

@end
