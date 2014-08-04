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
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE;


@interface TAASErrorResponse ()

@property (        nonatomic) NSInteger                  statusCode;

@end


@implementation TAASErrorResponse

- (id)initWithStatusCode:(int)statusCode
                 andBody:(NSString *)string {
    if (string == nil) string = @"";
    NSData *body =
                [[NSString stringWithFormat:@"<html><head><title>%@</title></head><body>%@</body></html>",
                      string, string] dataUsingEncoding:NSUTF8StringEncoding];

    if ((self = [super initWithData:body])) {
      HTTPLogInfo(@"%@[%p]: initWithStatusCode: %d", THIS_FILE, self, statusCode);

        self.statusCode = statusCode;
    }
    return self;
}

- (NSInteger) status {
    HTTPLogTrace2(@"%@[%p]: status: %lu", THIS_FILE, self, (unsigned long)self.statusCode);

    return self.statusCode;
}

@end
