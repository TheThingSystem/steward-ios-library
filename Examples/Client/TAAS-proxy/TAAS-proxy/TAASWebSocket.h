//
//  TAASWebSocket.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "WebSocket.h"
#import "SRWebSocket.h"


@interface TAASWebSocket : WebSocket <SRWebSocketDelegate>

@property (strong, nonatomic) NSURLRequest      *resource;
@property (strong, nonatomic) SRWebSocket       *downstream;
@property (        nonatomic) BOOL               authenticate;
@property (        nonatomic) BOOL               opened;
@property (        nonatomic) BOOL               followup;

- (id)initWithRequest:(HTTPMessage *)request
            andSocket:(GCDAsyncSocket *)socket
          forResource:(NSURLRequest *)resource;

@end
