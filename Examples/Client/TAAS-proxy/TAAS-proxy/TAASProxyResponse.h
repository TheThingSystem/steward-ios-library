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

@property (        nonatomic) BOOL               oneshotP;
@property (strong, nonatomic) NSString          *behavior;
@property (strong, nonatomic) NSMutableData     *body;

@property (strong, nonatomic) HTTPConnection    *upstream;
@property (strong, nonatomic) NSURLConnection   *downstream;
@property (        nonatomic) UInt64             dataOffset;
@property (        nonatomic) NSInteger          statusCode;
@property (strong, nonatomic) NSMutableDictionary
                                                *headerFields;
@property (strong, nonatomic) NSMutableData     *data;

- (id)initWithURI:(NSString *)URI
    forConnection:(HTTPConnection *)connection;

@end
