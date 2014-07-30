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

@property (strong, nonatomic) NSMutableArray            *downstreams;

@end


// http://127.0.0.1:8884/oneshot?behavior=report&entity=device&id=129&properties=temperature,humidity,...

@implementation TAASReport

+ (TAASReport *)singleton {
    static TAASReport *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{ shared = [[TAASReport alloc] init]; });
    return shared;
}

- (id) init {
    if ((self = [super init])) {
      self.downstreams = [NSMutableArray array];
    }

    return self;
}
- (void)generateReport:(NSDictionary *)dictionary {
    DDLogVerbose(@"report: %@", dictionary);

    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:(dictionary.count + 1)];
    [parameters addEntriesFromDictionary:dictionary];
    [parameters setObject:@"report" forKey:@"behavior"];

    NSString *URI = [NSString stringWithFormat:@"http://127.0.0.1:8884/oneshot?%@",
                       [NSString URLQueryWithParameters:parameters]];
    [self.downstreams addObject:[[TAASProxyResponse alloc] initWithURI:URI forConnection:(HTTPConnection *)self]];
}

- (void)responseHasAvailableData:(TAASProxyResponse *)child {
    if (child.downstream == nil) [self.downstreams removeObject:child];
}

- (void)responseDidAbort:(TAASProxyResponse *)child {
    [self.downstreams removeObject:child];
}

@end
