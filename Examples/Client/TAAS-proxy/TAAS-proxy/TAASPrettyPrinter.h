//
//  TAASPrettyPrinter.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 7/8/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MHPrettyDate.h"


#define kKeyLength    (12)

@interface TAASPrettyPrinter : NSObject

+ (TAASPrettyPrinter *)singleton;

- (NSString *)infoPP:(NSDictionary *)info;
- (NSString *)valuesPP:(id)value;

@end


@interface MHPrettyDate (TAAS)

+ (NSString *)shortPrettyDateWithDate:(NSDate *)date;
+ (NSString *)shortPrettyDateFromDate:(NSDate *)date;

@end
