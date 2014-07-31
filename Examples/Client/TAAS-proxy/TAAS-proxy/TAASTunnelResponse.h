//
//  TAASTunnelResponse.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "HTTPResponse.h"
#import "HTTPConnection.h"
#import "GCDAsyncSocket.h"


@interface TAASTunnelResponse : NSObject <HTTPResponse>

@property (strong, nonatomic) GCDAsyncSocket    *downstream;


- (id)initWithPath:(NSString *)path
        fromSocket:(GCDAsyncSocket *)socket
     forConnection:(HTTPConnection *)connection;

@end
