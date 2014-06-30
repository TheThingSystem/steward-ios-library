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
    DDLogVerbose(@"reachability=%ld",  (long)self.fxReachabilityStatus);

    struct ifaddrs *addrs, *ifa;
    if (getifaddrs(&addrs) != 0) {
        DDLogError(@"%s: getifaddrs failed", __FUNCTION__);
        return;
    }

// TODO: when network address changes, restart steward and proxy
    for (ifa = addrs; ifa; ifa = ifa -> ifa_next) {
        if (ifa -> ifa_flags & IFF_LOOPBACK) continue;


    }

    freeifaddrs(addrs);
}

@end
