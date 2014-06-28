//
//  TAASWebSocket.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASWebSocket.h"
#import "AppDelegate.h"
#import "HTTPMessage.h"
#import "TAASClient.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_INFO;


@interface TAASWebSocket ()

@property (strong, nonatomic) NSURLRequest              *resource;
@property (strong, nonatomic) SRWebSocket               *downstream;
@property (        nonatomic) BOOL                       authenticate;
@property (        nonatomic) BOOL                       opened;
@property (        nonatomic) BOOL                       followup;

@end


@implementation TAASWebSocket

- (id)initWithRequest:(HTTPMessage *)message
            andSocket:(GCDAsyncSocket *)socket
          forResource:(NSURLRequest *)resource {
  if ((self = [super initWithRequest:message socket:socket]) != nil) {
    self.resource = resource;
  }

  return self;
}

- (void)didOpen {
    DDLogVerbose(@"didOpen: %@", [[request url] relativeString]);

    self.downstream = [[SRWebSocket alloc] initWithURLRequest:self.resource];
    self.downstream.delegate = self;
    AppDelegate *appDelegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    TAASClient *service = [appDelegate rootController].service;
    self.authenticate = service.authenticate;
    self.opened = NO;
    [self.downstream open];
}

- (void)didReceiveMessage:(NSString *)message {
    DDLogVerbose(@"didReceiveMessage:%@", message);

    [super didReceiveMessage:message];

    if (self.downstream != nil) [self.downstream send:message];
}

- (void)didClose {
    DDLogVerbose(@"didClose");

    if (self.downstream != nil) [self.downstream close];
    if (!self.opened) [super didClose];
}


#pragma mark - SRWebSocket delegate methods

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    self.opened = YES;
    if (self.authenticate == NO) {
      [super didOpen];
      return;
    }

    AppDelegate *appDelegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    TAASClient *service = [appDelegate rootController].service;
    NSString *json = [service authenticatorJSON];
    DDLogVerbose(@"send downstream %@", json);
    [self.downstream send:json];
}

- (void)webSocket:(SRWebSocket *)webSocket
didReceiveMessage:(id)message {
    if (!self.authenticate) {
        DDLogVerbose(@"webSocket:%@ didReceiveMessage:%@", webSocket, message);
        [self sendMessage:(NSString *)message];
        return;
    }
    DDLogVerbose(@"recv downstream %@", message);

    NSError *error = nil;
    NSData *data = [((NSString *) message) dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&error];
    NSDictionary *oops = [dictionary objectForKey:@"error"];
    if (oops == nil) {
      self.authenticate = NO;
      [super didOpen];
      return;
    }

    NSString *diagnostic = [oops objectForKey:@"diagnostic"];
    if (diagnostic == nil) diagnostic = message;
    dictionary = [NSDictionary dictionaryWithObject:diagnostic
                                             forKey:NSLocalizedDescriptionKey];

    [self webSocket:webSocket didFailWithError:[NSError errorWithDomain:@"com.thethingsystem.TAAS-proxy"
                                                                   code:1
                                                               userInfo:dictionary]];
}

- (void)webSocket:(SRWebSocket *)webSocket
 didFailWithError:(NSError *)error {
    DDLogError(@"webSocket:%@ didFailWithError:%@", webSocket, error);

    [self.downstream close];
    self.opened = NO;
    [self stop];
}

- (void)webSocket:(SRWebSocket *)webSocket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {
    self.opened = NO;
    [self stop];
}

@end
