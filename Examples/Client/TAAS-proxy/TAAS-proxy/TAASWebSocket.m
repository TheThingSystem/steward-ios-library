//
//  TAASWebSocket.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 5/9/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASWebSocket.h"
#import "Client.h"
#import "HTTPMessage.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_INFO;


@implementation TAASWebSocket

- (id)initWithRequest:(HTTPMessage *)message
            andSocket:(GCDAsyncSocket *)socket
          forResource:(NSURLRequest *)resource {
  if ((self = [super initWithRequest:message socket:socket])) {
    self.resource = resource;
  }

  return self;
}

- (void)didOpen {
    DDLogInfo(@"didOpen: %@", [[request url] relativeString]);

    self.downstream = [[SRWebSocket alloc] initWithURLRequest:self.resource];
    self.downstream.delegate = self;
    self.authenticate = [Client sharedClient].authenticate;
    self.opened = NO;
    [self.downstream open];
}

- (void)didReceiveMessage:(NSString *)message {
    DDLogVerbose(@"didReceiveMessage:%@", message);

    [super didReceiveMessage:message];

    if (self.downstream != nil) [self.downstream send:message];
}

- (void)didClose {
    DDLogInfo(@"didClose");

    if (self.downstream != nil) [self.downstream close];
    if (!self.opened) [super didClose];
}


#pragma mark - SRWebSocket delegate methods

#define AUTHENTICATE_USER \
        @"{\"path\":\"/api/v1/user/authenticate/%@\",\"requestID\":\"%d\",\"response\":\"%@\"}"

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    DDLogInfo(@"webSocketDidOpen:%@", webSocket);

    self.opened = YES;
    if (self.authenticate == NO) {
      [super didOpen];
      return;
    }

    Client *client = [Client sharedClient];
    NSString *json = [NSString stringWithFormat:AUTHENTICATE_USER,
                               client.clientID, client.requestCounter, [client generateTOTP]];
    DDLogInfo(@"send downstream %@", json);
    client.requestCounter++;
    [self.downstream send:json];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    if (!self.authenticate) {
        DDLogVerbose(@"webSocket:%@ didReceiveMessage:%@", webSocket, message);
        [self sendMessage:(NSString *)message];
        return;
    }
    DDLogInfo(@"recv downstream %@", message);

    NSError *error = nil;
    NSData *data = [((NSString *) message) dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&error];
    NSDictionary *oops = (NSDictionary *)[dictionary objectForKey:@"error"];
    if (oops == nil) {
      self.authenticate = NO;
      [super didOpen];
      return;
    }

    NSString *diagnostic = [((NSDictionary *)oops) objectForKey:@"diagnostic"];
    if (diagnostic == nil) diagnostic = message;
    dictionary = [NSDictionary dictionaryWithObject:diagnostic
                                             forKey:NSLocalizedDescriptionKey];

    [self webSocket:webSocket didFailWithError:[NSError errorWithDomain:@"com.thethingsystem.TAAS-proxy"
                                                                   code:1
                                                               userInfo:dictionary]];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    DDLogInfo(@"webSocket:%@ didFailWithError:%@", webSocket, error);

    [self.downstream close];
    self.opened = NO;
    [self stop];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    DDLogInfo(@"webSocket:%@ didCloseWithCode:%ld reason:%@ wasClean:%d", webSocket, (long)code, reason, wasClean);

    self.opened = NO;
    [self stop];
}

@end
