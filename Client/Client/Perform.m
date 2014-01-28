//
//  Perform.m
//  Client
//
//  Created by Alasdair Allan on 26/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "Client.h"

@implementation Perform

- (id)initWithAddress:(NSString *)ipAddress {
	if( (self = [super init]) ) {
        NSString *request = [NSString stringWithFormat:@"wss://%@:8888/manage", ipAddress];
        self.webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:request]]];
        self.webSocket.delegate = self;
        self.authenticate = [Client sharedClient].authenticate;
        self.opened = NO;
    }
    return self;
}

- (void)performWithDevice:(NSString *)device andRequest:(NSString *)request andParameters:(NSString *)parameters {
    self.device = device;
    self.request = request;
    if ( parameters.length == 0 ) {
       self.parameters = @"\"\"";
    } else {
       self.parameters = [NSString stringWithFormat:@"\"%@\"",parameters];
    }
    [self.webSocket open];
}

#pragma mark - SRWebSocketDelegate Methods

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSLog(@"webSocket: %@ didRecieveMessage:", webSocket);
    if ( [self.delegate respondsToSelector:@selector(recievedPerformResponse:)]  ) {
        [self.delegate recievedPerformResponse:(NSString *)message];
    }
    if ( self.authenticate == YES && self.opened == YES ) {
        NSString *json = [NSString stringWithFormat:@"{\"path\":\"/api/v1/actor/perform/%@\",\"requestID\":\"%d\",\"perform\":\"%@\",\"parameter\":%@}", self.device, [Client sharedClient].requestCounter, self.request, self.parameters ];
        NSLog(@"json = %@", json);
        [Client sharedClient].requestCounter = [Client sharedClient].requestCounter + 1;
        [webSocket send:json];
    }
    
    //[webSocket close];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"webSocketDidOpen: %@", webSocket);
    NSString *json;
    if (self.authenticate == YES && self.opened == NO ) {
        json = [NSString stringWithFormat:@"{\"path\":\"/api/v1/user/authenticate/%@\",\"requestID\":\"%d\",\"response\":\"%@\"}", [Client sharedClient].clientID, [Client sharedClient].requestCounter, [[Client sharedClient] generateTOTP]];
    } else {
        json = [NSString stringWithFormat:@"{\"path\":\"/api/v1/actor/perform/%@\",\"requestID\":\"%d\",\"perform\":\"%@\",\"parameter\":%@}", self.device, [Client sharedClient].requestCounter, self.request, self.parameters ];
    }
    NSLog(@"json = %@", json);
    [Client sharedClient].requestCounter = [Client sharedClient].requestCounter + 1;
    [webSocket send:json];
    self.opened = YES;
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"webSocket: %@ didFailWithError:%@", webSocket, error);
    [webSocket close];
    self.opened = NO;

}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"webSocket: %@ didCloseWithCode:%ld reason:'%@' wasClean:%d", webSocket, (long)code, reason, wasClean);
    self.opened = NO;
    
}

@end
