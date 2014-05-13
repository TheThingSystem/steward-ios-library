//
//  TAASConnection.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "HTTPConnection.h"
#import "TAASProxyResponse.h"
#import "TAASWebSocket.h"


@interface TAASConnection : HTTPConnection

@property (strong, nonatomic) TAASProxyResponse *response;
@property (strong, nonatomic) TAASWebSocket     *ws;

@end
