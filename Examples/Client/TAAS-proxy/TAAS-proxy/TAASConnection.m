//
//  TAASConnection.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASConnection.h"
#import "Client.h"
#import "HTTPFileResponse.h"
#import "TAASErrorResponse.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation TAASConnection

// TODO: create error response bodies

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
    NSString *filePath = [self filePathForURI:path allowDirectory:NO];
    NSString *documentRoot = [config documentRoot];

    if ((filePath != nil) && ([filePath hasPrefix:documentRoot])) {
      BOOL isDir = NO;
      if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir]) {
        if (!isDir) {
          DDLogVerbose(@"serving local file %@", filePath);
          return [[HTTPFileResponse alloc] initWithFilePath:filePath forConnection:self];
        }

        DDLogError(@"filePath is a directory: %@", filePath);
return [[TAASErrorResponse alloc] initWithStatusCode:403 andBody:nil];
      }
    }

    Client *client = [Client sharedClient];
    if ((client == nil) || (client.steward == nil) || (client.steward.ipAddress == nil)) {

return [[TAASErrorResponse alloc] initWithStatusCode:504 andBody:nil];
    }

    self.response = [[TAASProxyResponse alloc]
                         initWithURI:[NSString stringWithFormat:@"http://%@:8887%@",
                                               client.steward.ipAddress, path]
                       forConnection:self];
    return self.response;
}

- (WebSocket *)webSocketForURI:(NSString *)path {
    Client *client = [Client sharedClient];
    if ((client == nil) || (client.steward == nil) || (client.steward.ipAddress == nil)) {

      return nil;
    }

    if ((![path isEqualToString:@"/console"]) && (![path isEqualToString:@"/manage"])) {
      return [super webSocketForURI:path];
    }

    NSString *string = [NSString stringWithFormat:@"ws://%@:8887%@",
                                 client.steward.ipAddress, path];
    NSURLRequest *URLrequest = [NSURLRequest requestWithURL:[NSURL URLWithString:string]];
    self.ws = [[TAASWebSocket alloc] initWithRequest:request
                                           andSocket:asyncSocket
                                         forResource:URLrequest];
    return self.ws;
}

@end
