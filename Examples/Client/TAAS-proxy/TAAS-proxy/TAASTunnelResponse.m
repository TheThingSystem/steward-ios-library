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


// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE | HTTP_LOG_FLAG_TRACE;


@interface TAASTunnelResponse ()

@property (strong, nonatomic) NSMutableData             *body;

@property (strong, nonatomic) HTTPConnection            *upstream;
@property (        nonatomic) UInt64                     dataOffset;
@property (strong, nonatomic) NSMutableData             *data;

@end


@implementation TAASTunnelResponse

- (id)initWithAddress:(NSString *)address
              andPort:(uint16_t)portno
        forConnection:(HTTPConnection *)connection {
    if ((self = [super init]))  {
        HTTPLogInfo(@"%@[%p]: initWithAddress:%@:%d", THIS_FILE, self, address, portno);

        self.upstream = connection;


        self.body = nil;

self.downstream = nil;
        if (self.downstream == nil) {
	    HTTPLogWarn(@"%@[%p]: unable to create connection to %@:%d", THIS_FILE, self, address, portno);
            return nil;
        }
// set runLoop for self.downstream

        self.dataOffset = 0;
        self.data = nil;
    }

    return self;
}

- (void)abort {
    HTTPLogTrace();

    if (self.downstream != nil) {
        [self.downstream disconnect];
        self.downstream = nil;
    }
    if (self.upstream != nil) [self.upstream responseDidAbort:self];
}

- (BOOL)isDone {
    HTTPLogTrace2(@"%@[%p]: isDone:%@", THIS_FILE, self,
                  (self.downstream != nil) || ((self.data != nil) && ([self.data length] > 0))
                      ? @"NO" : @"YES");

    if ((self.downstream != nil) || ((self.data != nil) && ([self.data length] > 0))) return NO;
    return YES;
}

- (void)connectionDidClose {
    HTTPLogTrace();

    self.upstream = nil;
}


#pragma mark - delayed response

- (BOOL)delayResponseHeaders {
    HTTPLogTrace2(@"%@[%p]: delayResponseHeaders", THIS_FILE, self);

    return YES;
}

- (NSInteger)status {
    HTTPLogTrace2(@"%@[%p]: status", THIS_FILE, self);

    return 0;
}

- (NSDictionary *)httpHeaders {
    HTTPLogTrace2(@"%@[%p]: httpHeaders:", THIS_FILE, self);

    return nil;
}

-(NSData *)readDataOfLength:(NSUInteger)length {
    HTTPLogTrace2(@"%@[%p]: readDataOfLength:%lu", THIS_FILE, self, (unsigned long)length);

    if (!self.data) return nil;

    if (length > [self.data length]) length = [self.data length];

    NSData *result = [NSData dataWithBytes:[self.data bytes] length:length];
    [self.data replaceBytesInRange:NSMakeRange(0, length) withBytes:NULL length:0];
    HTTPLogTrace2(@"%@[%p]: returning %lu octets, %lu octets remaining", THIS_FILE, self,
                  (unsigned long)length, (unsigned long)[self.data length]);

    self.dataOffset += length;
    return result;
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
    HTTPLogTrace2(@"%@[%p]: offset:%lu", THIS_FILE, self, (unsigned long)self.dataOffset);

    return self.dataOffset;
}

- (void)setOffset:(UInt64)offset {
    HTTPLogTrace2(@"%@[%p]: setOffset:%lu", THIS_FILE, self, (unsigned long)offset);
}


#pragma mark - GCDAsyncSocket delegate methods

-   (void)socket:(GCDAsyncSocket *)sock
didConnectToHost:(NSString *)host
	    port:(uint16_t)port {
}

- (void)socket:(GCDAsyncSocket *)sock
   didReadData:(NSData *)data
       withTag:(long)tag {

  // give it to self.connection...

}

-      (void)socket:(GCDAsyncSocket *)sock
didWriteDataWithTag:(long)tag {
    HTTPLogError(@"%@[%p] didWriteDataWIthTag: %ld", THIS_FILE, self, tag);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
		  withError:(NSError *)error {
    HTTPLogError(@"%@[%p] socketDidDisconnect: %@", THIS_FILE, self, error);

    [self abort];
}

@end
