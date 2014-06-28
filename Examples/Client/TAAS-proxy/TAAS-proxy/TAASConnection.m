//
//  TAASConnection.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASConnection.h"
#import "AppDelegate.h"
#import "HTTPFileResponse.h"
#import "TAASClient.h"
#import "TAASErrorResponse.h"
#import "TAASProxyResponse.h"
#import "TAASWebSocket.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface TAASConnection ()

@property (strong, nonatomic) TAASProxyResponse         *response;
@property (strong, nonatomic) TAASWebSocket             *ws;

@end


@implementation TAASConnection

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method
                                              URI:(NSString *)path {
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
        return [[TAASErrorResponse alloc] initWithStatusCode:403
                                                     andBody:[self dataForBody:@"403 Forbidden"]];
      }
    }

    AppDelegate *appDelegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    TAASClient *service = [appDelegate rootController].service;
    NSString *serviceURI = [service serviceURI:path];
    if (serviceURI == nil) {
        return [[TAASErrorResponse alloc] initWithStatusCode:503
                                                     andBody:[self dataForBody:@"503 Not Connected"]];
    }

    self.response = [[TAASProxyResponse alloc] initWithURI:serviceURI
                                             forConnection:self];
    return self.response;
}

- (WebSocket *)webSocketForURI:(NSString *)path {
    AppDelegate *appDelegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    TAASClient *service = [appDelegate rootController].service;
    NSString *serviceURI = [service serviceURI:path];
    if (serviceURI == nil) {

      return nil;
    }

    if ((![path isEqualToString:@"/console"]) && (![path isEqualToString:@"/manage"])) {
      return [super webSocketForURI:path];
    }

    NSURLRequest *URLrequest = [NSURLRequest requestWithURL:[NSURL URLWithString:serviceURI]];
    self.ws = [[TAASWebSocket alloc] initWithRequest:request
                                           andSocket:asyncSocket
                                         forResource:URLrequest];
    return self.ws;
}

- (NSData *)dataForBody:(NSString *)reason {
  return [[NSString stringWithFormat:@"<html><head><title>%@</title></head><body>%@</body></html>",
                    reason, reason]
              dataUsingEncoding:NSUTF8StringEncoding];
}

@end
