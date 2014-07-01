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
  return [self initWithAddress:ipAddress andPort:8888];
}

- (id)initWithAddress:(NSString *)ipAddress andPort:(long)port {
  NSString *URI = [NSString stringWithFormat:@"wss://%@:%ld/console", ipAddress, port];

  return [self initWithURLRequest:[NSURL URLWithString:URI]];
}

- (id)initWithURLRequest:(NSURLRequest *)request {
    if( (self = [super init]) ) {
        self.webSocket = [[SRWebSocket alloc] initWithURLRequest:request];
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
//  NSLog(@"webSocket: %@ didReceiveMessage:", webSocket);
    if ( [self.delegate respondsToSelector:@selector(receivedEventMessage:)] ) {
        [self.delegate receivedEventMessage:(NSString *)message];
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    NSLog(@"webSocketDidOpen: %@", webSocket);
    if ( [self.delegate respondsToSelector:@selector(startedMonitoring)] ) {
        [self.delegate startedMonitoring];
    }
    
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"webSocket: %@ didFailWithError:%@", webSocket, error);
    [webSocket close];
    if ( [self.delegate respondsToSelector:@selector(monitoringFailedWithError:)] ) {
        [self.delegate monitoringFailedWithError:error];
    }

}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"webSocket: %@ didCloseWithCode:%ld reason:'%@' wasClean:%d", webSocket, (long)code, reason, wasClean);
    if ( [self.delegate respondsToSelector:@selector(monitoringClosedWithCode:)] ) {
        [self.delegate monitoringClosedWithCode:code];
    }
   
}




@end
