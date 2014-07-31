//
//  TAASTunnelResponse.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 7/31/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASTunnelResponse.h"
#import "AppDelegate.h"
#import "RequestUtils.h"
#import "HTTPLogging.h"
#import "HTTPMessage.h"


// Log levels : off, error, warn, info, verbose
// Other flags: HTTP_LOG_FLAG_TRACE
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE;


@interface TAASTunnelResponse ()

@property (        nonatomic) BOOL                       connectedP;
@property (        nonatomic) BOOL                       errorP;

@property (strong, nonatomic) HTTPConnection            *parent;

@property (strong, nonatomic) GCDAsyncSocket            *upstream;
@property (nonatomic, weak) id<GCDAsyncSocketDelegate>   pDelegate;
@property (        nonatomic) dispatch_queue_t           pQueue;

@property (        nonatomic) dispatch_queue_t           delegateQueue;

@end


@implementation TAASTunnelResponse

- (id)initWithPath:(NSString *)path
        fromSocket:(GCDAsyncSocket *)socket
     forConnection:(HTTPConnection *)connection {
    if ((self = [super init]))  {
        uint16_t port = 80;
        NSString *host = path;
        NSRange range = [host rangeOfString:@":"];
        if (range.location != NSNotFound) {
            port = [[host substringFromIndex:(range.location + 1)] intValue];
            host = [host substringToIndex:range.location];
        }
        HTTPLogInfo(@"%@[%p]: initWithPath: %@:%lu", THIS_FILE, self, host, (unsigned long)port);
// NB: the second part of fail-friendly
       range = [host rangeOfString:@".google.com" options:(NSBackwardsSearch | NSAnchoredSearch)];
       if ((range.location != NSNotFound) || ([host isEqualToString:@"google.com"])) {
           host = @"127.0.0.1";
           port = (port == 443) ? 8883 : 8884;
       }

        self.delegateQueue = dispatch_queue_create("TAASTunnelResponse socket delegate queue", 0);

        self.parent = connection;
        self.upstream = socket;
        self.pDelegate = self.upstream.delegate;
        self.upstream.delegate = self;
        self.pQueue = self.upstream.delegateQueue;
        self.upstream.delegateQueue = self.delegateQueue;
        self.downstream = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.delegateQueue];

        NSError *error = nil;
        [self.downstream connectToHost:host onPort:port error:&error];
        self.connectedP = self.errorP = NO;
    }

    return self;
}

- (void)abort {
    HTTPLogTrace();

    if (self.downstream != nil) {
        [self.downstream disconnect];
        self.downstream = nil;
    }
    if (self.parent == nil) return;

    self.upstream.delegate = self.pDelegate;
    self.upstream.delegateQueue = self.pQueue;
    self.upstream = nil;
    [self.parent responseDidAbort:self];
}

- (BOOL)isDone {
    HTTPLogTrace2(@"%@[%p]: isDone: %@", THIS_FILE, self, (self.downstream == nil) ? @"YES" : @"NO");

    return (self.downstream == nil);
}

- (void)connectionDidClose {
    HTTPLogTrace();

    if (self.upstream != nil) {
        self.upstream.delegate = self.pDelegate;
        self.upstream.delegateQueue = self.pQueue;
        self.upstream = nil;
    }
    self.parent = nil;
}


#pragma mark - delayed response

- (BOOL)delayResponseHeaders {
    HTTPLogTrace2(@"%@[%p]: delayResponseHeaders: %@", THIS_FILE, self, self.errorP ? @"NO" : @"YES");

    return (!self.errorP);
}

- (NSInteger)status {
    HTTPLogTrace2(@"%@[%p]: status:%d", THIS_FILE, self, 504);

    return 504;
}

- (NSDictionary *)httpHeaders {
    HTTPLogTrace();

    return nil;
}

-(NSData *)readDataOfLength:(NSUInteger)length {
    HTTPLogTrace2(@"%@[%p]: readDataOfLength: %lu", THIS_FILE, self, (unsigned long)length);

    return nil;
}


#pragma mark - dynamic data

- (BOOL)isChunked {
    HTTPLogTrace();

    return YES;
}

- (UInt64)contentLength {
    HTTPLogTrace();

    return 0;
}

- (UInt64)offset {
    HTTPLogTrace();

    return 0;
}

- (void)setOffset:(UInt64)offset {
    HTTPLogTrace2(@"%@[%p]: setOffset: %lu", THIS_FILE, self, (unsigned long)offset);
}


#pragma mark - GCDAsyncSocket delegate methods

#define TUNNEL_CONNECTED    2000
#define TUNNEL_CONFIRMED    2001
#define TUNNEL_READ         2002
#define TUNNEL_WRITE        2003

-   (void)socket:(GCDAsyncSocket *)sock
didConnectToHost:(NSString *)host
            port:(uint16_t)port {
    HTTPLogTrace2(@"%@[%p]: didConnectToHost: %@:%lu", THIS_FILE, self, host, (unsigned long)port);

    [self socket:self.downstream
     didReadData:[[NSString stringWithFormat:@"HTTP/1.0 200 OK\r\n\r\n"]
                   dataUsingEncoding:NSUTF8StringEncoding]
         withTag:TUNNEL_CONNECTED];
    self.connectedP = YES;
}

- (void)socket:(GCDAsyncSocket *)sock
   didReadData:(NSData *)data
       withTag:(long)tag {
    HTTPLogTrace2(@"%@[%p]: didReadData: %@ length=%lu tag=%lu", THIS_FILE, self,
                  (sock == self.downstream) ? @"downstream" : @"upstream", (unsigned long)data.length,
                  tag);

    GCDAsyncSocket *peer = (sock == self.downstream) ? self.upstream : self.downstream;

    [peer writeData:data withTimeout:-1 tag:tag];
    [peer readDataWithTimeout:-1 tag:TUNNEL_READ];
    [sock readDataWithTimeout:-1 tag: TUNNEL_READ];
}

-      (void)socket:(GCDAsyncSocket *)sock
didWriteDataWithTag:(long)tag {
    HTTPLogTrace2(@"%@[%p]: didWriteDataWithTag: %@ tag=%lu", THIS_FILE, self,
                  (sock != self.downstream) ? @"upstream" : @"downstream", tag);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
                  withError:(NSError *)error {
    HTTPLogError(@"%@[%p] socketDidDisconnect: %@", THIS_FILE, self, error);

    if (self.connectedP) {
        [self abort];
        return;
    }

    self.errorP = YES;
    [self.parent responseHasAvailableData:self];
}

@end
