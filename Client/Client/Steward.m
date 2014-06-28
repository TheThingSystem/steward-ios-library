//
//  Steward.m
//  Client
//
//  Created by Alasdair Allan on 12/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "Client.h"

@implementation Steward

- (id)init {
	if( (self = [super init]) ) {
        self.ipAddress = @"steward.local";
    }
    return self;
}

- (void)findSteward {
    NSLog(@"Starting search for steward");
    self.browser = [NSNetServiceBrowser new];
    [self.browser scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    self.browser.delegate = self;
    [self.browser searchForServicesOfType:@"_wss._tcp." inDomain:@""];
}


// -----------------------------------------------------------------------------
#pragma mark - NSCoder methods

- (id)initWithCoder:(NSCoder *)decoder {
	if ((self = [super init])) {
        self.ipAddress = [decoder decodeObjectForKey:@"ipAddress"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.ipAddress forKey:@"ipAddress"];
}

// -----------------------------------------------------------------------------
#pragma mark - NSNetServiceBrowser Delegate Methods

// Sent when browsing begins
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser {
    NSLog(@"Searching");
}

// Sent when browsing stops
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser {
    NSLog(@"Stopped Searching");

    if ( [self.delegate respondsToSelector:@selector(stewardDidStopSearching)] ) {
        [self.delegate stewardDidStopSearching];
    }
}

// Sent if browsing fails
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict {
    NSLog(@"Did not search with error %@", errorDict);

    if ( [self.delegate respondsToSelector:@selector(stewardNotSearchedWithErrorDict:)] ) {
        [self.delegate stewardNotSearchedWithErrorDict:errorDict];
    }
}

// Sent when a service appears
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)netService moreComing:(BOOL)moreComing {
    NSLog(@"Got service %p with hostname %@\n", netService, netService.hostName );
    NSLog(@"aNetService = %@", netService);
    if( [netService.name isEqualToString:@"steward"] ) {
        NSLog(@"Found the steward");
        self.service = netService;
        [self.service setDelegate:self];
        [self.service resolveWithTimeout:5];
    }
    
    if(!moreComing) {
        NSLog(@"More coming");
    }
}

// Sent when a service disappears
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing {
    NSLog(@"Lost service %p from hostname %@\n", netService, [netService hostName]);
    if(!moreComing) {
        NSLog(@"More coming");
    }
}

// -----------------------------------------------------------------------------
#pragma mark - NSNetService Delegate Methods

- (void)netServiceWillResolve:(NSNetService *)sender {
    NSLog(@"Resolving service");

}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSLog(@"Service resolved. Host name: %@, Port number: %@, Addresses: %@", [sender hostName],
          [NSNumber numberWithUnsignedShort:[sender port]], [sender ipAddresses]);

    NSArray *ipAddresses = [sender ipAddresses];
    self.ipAddress = ipAddresses.count > 0 ? [ipAddresses objectAtIndex:0] : nil;
    if ( [self.delegate respondsToSelector:@selector(stewardFoundAtService:)] ) {
        [self.delegate stewardFoundAtService:sender];
        return;
    }
    [self.delegate stewardFoundWithAddress:self.ipAddress];

}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    NSLog(@"Could not resolve service. %@", errorDict);

    if ( [self.delegate respondsToSelector:@selector(stewardNotResolvedWithErrorDict:)] ) {
        [self.delegate stewardNotResolvedWithErrorDict:errorDict];
    }
}

@end


@implementation NSNetService(ipAddresses)

#include <arpa/inet.h>

- (NSArray *)ipAddresses {
    NSArray *addrs = [self addresses];
    NSMutableArray *ipaddrs = [NSMutableArray arrayWithCapacity:addrs.count];

    for (NSData *a in addrs) {
        struct sockaddr *addr = (struct sockaddr *)[a bytes];
        if (addr->sa_family != AF_INET) continue;

        struct sockaddr_in *sin = (struct sockaddr_in *)addr;

        char ipaddr[INET_ADDRSTRLEN];
        if (!inet_ntop(sin->sin_family, &sin->sin_addr, ipaddr, sizeof ipaddr)) continue;
        NSString *ipaddress = [NSString stringWithFormat:@"%s", ipaddr];
        if ([ipaddrs indexOfObject:ipaddress] == NSNotFound) [ipaddrs addObject:ipaddress];
    }

    return ipaddrs;
}

@end
