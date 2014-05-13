//
//  TAASErrorResponse.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASErrorResponse.h"
#import "HTTPLogging.h"


// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE | HTTP_LOG_FLAG_TRACE;


@implementation TAASErrorResponse

- (id)initWithStatusCode:(int)statusCode andBody:(NSData *)body {
    if (body == nil) body = [NSData data];

    if ((self = [super initWithData:body])) {
        HTTPLogTrace();

        self.statusCode = statusCode;
    }
    return self;
}

- (NSInteger) status {
    HTTPLogTrace();

    return self.statusCode;
}

@end
