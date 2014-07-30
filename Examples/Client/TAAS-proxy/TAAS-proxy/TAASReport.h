//
//  TAASReport.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 7/30/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "HTTPResponse.h"
#import "HTTPConnection.h"


@interface TAASReport : NSObject

+ (TAASReport *)singleton;
- (void)generateReport:(NSDictionary *)dictionary;

@end
