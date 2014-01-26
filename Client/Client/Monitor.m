//
//  Monitor.m
//  Client
//
//  Created by Alasdair Allan on 26/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "Client.h"


@implementation Monitor


- (id)initWithAddress:(NSString *)ipAddress {
	if( (self = [super init]) ) {
        NSString *request = [NSString stringWithFormat:@"wss://%@:8888/console", ipAddress];
        NSLog(@"Address is %@", request);
        self.webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:request]]];
        self.webSocket.delegate = self;
    }
    return self;
}

- (void)startMonitoringEvents {
    [self.webSocket open];
    
}

- (void)stopMonitoringEvents {
    [self.webSocket close];
}

#pragma mark - SRWebSocketDelegate Methods

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    //NSLog(@"eventSocket: %@ didRecieveMessage: %@", webSocket, message);
    NSLog(@"webSocket: %@ didRecieveMessage:", webSocket);
    if ( [self.delegate respondsToSelector:@selector(recievedEventMessage:)] ) {
        [self.delegate recievedEventMessage:(NSString *)message];
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"webSocketDidOpen: %@", webSocket);
    
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"webSocket: %@ didFailWithError:%@", webSocket, error);
    [webSocket close];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"webSocket: %@ didCloseWithCode:%ld reason:'%@' wasClean:%d", webSocket, (long)code, reason, wasClean);
    
}




@end