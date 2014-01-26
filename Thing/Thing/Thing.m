//
//  Thing.m
//  Thing
//
//  Created by Alasdair Allan on 08/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//  This code is released under the MIT license.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "Thing.h"
#import "GCDAsyncUdpSocket.h"

@implementation Thing

- (id)init {
	
	if( (self = [super init]) ) {
		self.debug = YES;
        self.steward = [[Steward alloc] init];
        self.steward.delegate = self;
        self.requestCounter = 1;
        //[self findSteward];
	}
	return self;
}

+ (Thing *)sharedThing {
    static Thing *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[Thing alloc] init]; });
    return shared;
}

// -----------------------------------------------------------------------------
#pragma mark - Instance Methods

- (void)findSteward {
    [self.steward findSteward];
}

- (void)dispatchWithInformation:(NSDictionary *)info {
    
    
    NSString *json = [NSString stringWithFormat:@"{\"path\":\"/api/v1/thing/reporting\",\"requestID\":\"%d\",\"things\":{\"%@\":{\"prototype\":{\"device\":{\"name\":\"%@\",\"maker\":\"%@\"},\"name\":true,\"status\":[\"present\",\"absent\",\"recent\"],\"properties\":{", self.requestCounter, self.device.device, self.device.name, self.device.maker];
    
    NSString *properties = @"";
    int count = 0;
    for ( NSString *key in self.device.properties) {
        count = count + 1;
        NSLog(@"%@ = %@", key, self.device.properties[key]);
        if ( count == self.device.properties.count ) {
            properties = [properties stringByAppendingFormat:@"\"\%@\":\"%@\"", key, self.device.properties[key]];
        } else {
            properties = [properties stringByAppendingFormat:@"\"\%@\":\"%@\",", key, self.device.properties[key]];
        }
    }
    json = [json stringByAppendingString:properties];
    json = [json stringByAppendingFormat:@"}},\"instances\":[{\"name\":\"%@\",\"status\":\"present\",\"unit\":{\"serial\":\"%@\",\"udn\":\"%@\"},\"info\":{",self.device.name, self.device.serial, self.device.udn];

    NSString *information = @"";
    count = 0;
    for ( NSString *key in info) {
        count = count + 1;
        NSLog(@"%@ = %@", key, info[key]);
        if ( count == self.device.properties.count ) {
            information = [information stringByAppendingFormat:@"\"\%@\":\"%@\"", key, info[key]];
        } else {
            information = [information stringByAppendingFormat:@"\"\%@\":\"%@\",", key, info[key]];
        }
    }
    json = [json stringByAppendingString:information];
    json = [json stringByAppendingFormat:@"},\"uptime\":\"%f\"}]}}}",[[NSProcessInfo processInfo] systemUptime]];
    
    NSLog(@"json = %@", json);
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    
    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [udpSocket enableBroadcast:YES error:nil];
    [udpSocket sendData:data toHost:@"224.0.9.1" port:22601 withTimeout:-1 tag:0];
    
    self.requestCounter = self.requestCounter + 1;
    
}

// -----------------------------------------------------------------------------
#pragma mark - NSCoding Methods

- (void)archiveDevice {
	NSLog(@"Saving %@ to Document Directory.", self.device);
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    NSString *file = [[Util documentsDirectoryPath] stringByAppendingPathComponent:@"device.plist"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createFileAtPath:file contents:data attributes:nil];
	NSLog(@"File = %@", file);
	
}

- (void)restoreDevice {
 	NSLog(@"Restoring device from Document Directory.");
    
    NSString *file = [[Util documentsDirectoryPath] stringByAppendingPathComponent: @"device.plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *data = [fileManager contentsAtPath:file];
    if ( [data length] > 0 ) {
        self.device = nil;
        self.device = (Device *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSLog(@"Restoring device.");
    } else {
        NSLog(@"No device to restore.");
    }
    
    
}

// -----------------------------------------------------------------------------
#pragma mark - Steward Delegate Methods

- (void)foundStewardWithAddress:(NSString *)ip {
    NSLog(@"Found steward with IP address of %@", ip);
    
}

- (void)stewardNotFoundWithError:(NSError *)error {
    
    
}

// -----------------------------------------------------------------------------
#pragma mark - Class Methods

+ (NSString *)version {
    return LIBRARY_VERSION;
}

@end
