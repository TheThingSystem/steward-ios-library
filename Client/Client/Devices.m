//
//  Devices.m
//  Client
//
//  Created by Alasdair Allan on 26/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "Client.h"

@implementation Devices

- (id)initWithAddress:(NSString *)ipAddress {
    return [self initWithAddress:ipAddress andPort:8888];
}

- (id)initWithAddress:(NSString *)ipAddress andPort:(long)port {
  NSString *URI = [NSString stringWithFormat:@"wss://%@:%ld/manage", ipAddress, port];

  return [self initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:URI]]];
}

- (id)initWithURLRequest:(NSURLRequest *)request {
    if( (self = [super init]) ) {
        self.webSocket = [[SRWebSocket alloc] initWithURLRequest:request];
        self.webSocket.delegate = self;
        self.oneShotP = YES;
        self.opened = NO;
    }
    return self;
}

- (NSUInteger)listAllDevices {
    if (!self.opened) {
      [self.webSocket open];
      return 0;
    }

    NSUInteger requestID = [Client sharedClient].requestCounter;
    NSString *json = [NSString stringWithFormat:@"{\"path\":\"/api/v1/actor/list\",\"requestID\":\"%lu\",\"options\":{\"depth\":\"all\"}}", (unsigned long)requestID];
    [Client sharedClient].requestCounter = requestID + 1;

    [self roundTrip:json];
    return requestID;
}

- (NSUInteger)listAllActivities {
    if (!self.opened) return [self listAllDevices];

    NSUInteger requestID = [Client sharedClient].requestCounter;
    NSString *json = [NSString stringWithFormat:@"{\"path\":\"/api/v1/activity/list\",\"requestID\":\"%lu\",\"options\":{\"depth\":\"all\"}}", (unsigned long)requestID];
    [Client sharedClient].requestCounter = requestID + 1;

    [self roundTrip:json];
    return requestID;
}

- (BOOL)roundTrip:(NSString *)json {
    if (!self.opened) return NO;

    NSLog(@"json = %@", json);
    [self.webSocket send:json];
    return YES;
}

- (void)stopListingDevices {
    [self.webSocket close];
}

#pragma mark - SRWebSocketDelegate Methods

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
//  NSLog(@"webSocket: %@ didReceiveMessage:", webSocket);
    if ( [self.delegate respondsToSelector:@selector(receivedDeviceList:)]  ) {
        [self.delegate receivedDeviceList:(NSString *)message];
    }
    if (self.oneShotP) [webSocket close];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"webSocketDidOpen: %@", webSocket);
    if ( [self.delegate respondsToSelector:@selector(startedListing)] ) {
        [self.delegate startedListing];
    }
    self.opened = YES;
    [self listAllDevices];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"webSocket: %@ didFailWithError:%@", webSocket, error);
    [webSocket close];
    if ( [self.delegate respondsToSelector:@selector(listingFailedWithError:)] ) {
        [self.delegate listingFailedWithError:error];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"webSocket: %@ didCloseWithCode:%ld reason:'%@' wasClean:%d", webSocket, (long)code, reason, wasClean);
    if ( [self.delegate respondsToSelector:@selector(listingClosedWithCode:)] ) {
        [self.delegate listingClosedWithCode:code];
    }
    
}

@end
