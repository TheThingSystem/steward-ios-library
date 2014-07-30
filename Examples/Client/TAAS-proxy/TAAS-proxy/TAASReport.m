//
//  TAASReport.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 7/30/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASReport.h"
#import "AppDelegate.h"
#import "TAASProxyResponse.h"
#import "RequestUtils.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;



@interface NSNumber (RequestUtils)

- (NSString *)URLEncodedString;

@end


@implementation NSNumber (RequestUtils)

- (NSString *)URLEncodedString {
    return [[NSString stringWithFormat:@"%@", self] URLEncodedString];
}

@end


@interface TAASReport ()

@property (strong, nonatomic) TAASProxyResponse         *downstream;

@end


// http://127.0.0.1:8884/oneshot?behavior=report&entity=device&id=129&properties=temperature,humidity,...

@implementation TAASReport

- (id)initWithDictionary:(NSDictionary *)dictionary {
    DDLogVerbose(@"report: %@", dictionary);

    if ((self = [super init])) {
        NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:(dictionary.count + 1)];
        [parameters addEntriesFromDictionary:dictionary];
        [parameters setObject:@"report" forKey:@"behavior"];

        NSString *URI = [NSString stringWithFormat:@"http://127.0.0.1:8884/oneshot?%@",
                           [NSString URLQueryWithParameters:parameters]];
        self.downstream = [[TAASProxyResponse alloc] initWithURI:URI forConnection:(HTTPConnection *)self];
    }

    return self;
}

- (void)responseHasAvailableData:(id)parent {
}

- (void)responseDidAbort:(id)parent {
}

@end
