//
//  Steward.m
//  Thing
//
//  Created by Alasdair Allan on 12/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "Thing.h"

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
}

// Sent if browsing fails
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)errorDict {
    NSLog(@"Did not search with error %@", errorDict);
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
    NSLog(@"Service resolved. Host name: %@ Port number: %@", [sender hostName], [NSNumber numberWithLong:[sender port]]);
    struct hostent *host_entry = gethostbyname([[sender hostName] cStringUsingEncoding:NSASCIIStringEncoding] );
    NSString *ip = [NSString stringWithCString:inet_ntoa(*((struct in_addr *)host_entry->h_addr_list[0])) encoding:NSASCIIStringEncoding];
    NSLog(@"IP address is %@", ip);
    self.ipAddress = ip;
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    NSLog(@"Could not resolve service. %@", errorDict);
}

@end
