//
//  TAASProxyResponse.h
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "HTTPResponse.h"
#import "HTTPConnection.h"


@interface TAASProxyResponse : NSObject <HTTPResponse>

- (id)initWithURI:(NSString *)URI
    forConnection:(HTTPConnection *)connection;

@end
