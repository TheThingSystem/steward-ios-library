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
  return [self initWithAddress:ipAddress andPort:8888 andOneShotP:YES];
}

- (id)initWithAddress:(NSString *)ipAddress andPort:(long)port andOneShotP:(BOOL)oneShotP {
    if( (self = [super init]) ) {
        NSString *request = [NSString stringWithFormat:@"wss://%@:%ld/manage", ipAddress, port];
        self.webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:request]]];
        self.webSocket.delegate = self;
        self.oneShotP = oneShotP;
        self.opened = NO;
    }
    return self;
}

- (void)listAllDevices {
    if (!self.opened) {
      [self.webSocket open];
      return;
    }

    NSString *json = [NSString stringWithFormat:@"{\"path\":\"/api/v1/actor/list\",\"requestID\":\"%d\",\"options\":{\"depth\":\"all\"}}", [Client sharedClient].requestCounter];
    NSLog(@"json = %@", json);
    [Client sharedClient].requestCounter = [Client sharedClient].requestCounter + 1;
    [self.webSocket send:json];
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
