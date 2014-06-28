//
//  TAASNetwork.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 6/28/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASNetwork.h"
#import <ifaddrs.h>
#import <net/if.h>
#import <arpa/inet.h>
#import "DDLog.h"
#import "DDTTYLogger.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface TAASNetwork ()
@end


@implementation TAASNetwork

+ (TAASNetwork *)sharedInstance {
    static TAASNetwork *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{ shared = [[TAASNetwork alloc] init]; });
    return shared;
}


- (id)init {
  if ((self = [super init])) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fxReachabilityStatusDidChange)
                                                 name:FXReachabilityStatusDidChangeNotification
                                               object:nil];
  }
  return self;
}


- (void)fxReachabilityStatusDidChange {
  self.fxReachabilityStatus = [FXReachability sharedInstance].status;
  DDLogVerbose(@"reachability=%d",  self.fxReachabilityStatus);
}

@end
