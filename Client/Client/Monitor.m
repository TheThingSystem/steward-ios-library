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
  return [self initWithAddress:ipAddress andPort:8888 andServiceType:NSURLNetworkServiceTypeDefault];
}

- (id)initWithAddress:(NSString *)ipAddress andPort:(long)port andServiceType:(NSURLRequestNetworkServiceType)serviceType {
    if( (self = [super init]) ) {
      NSString *request = [NSString stringWithFormat:@"wss://%@:%ld/console", ipAddress, port];
        NSLog(@"Address is %@", request);
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:request]];
        [urlRequest setNetworkServiceType:serviceType];
        self.webSocket = [[SRWebSocket alloc] initWithURLRequest:urlRequest];
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
