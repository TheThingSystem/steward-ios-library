//
//  Client.m
//  Client
//
//  Created by Alasdair Allan on 08/01/2014.
//  Copyright (c) 2014 The Client System. All rights reserved.
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

#import "Client.h"
#import "GCDAsyncUdpSocket.h"
#import "TOTPGenerator.h"
#import "OTPAuthURL.h"

@implementation Client

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

+ (Client *)sharedClient {
    static Client *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[Client alloc] init]; });
    return shared;
}

// -----------------------------------------------------------------------------
#pragma mark - Client Methods
- (void)findSteward {
    [self.steward findSteward];
}

- (void)availableDevices {
    self.devices = [[Devices alloc] initWithAddress:self.steward.ipAddress];
    self.devices.delegate = self;
    [self.devices listAllDevices];
    NSLog(@"Listing devices");
}

- (void)startMonitoringEvents {
    self.monitor = [[Monitor alloc] initWithAddress:self.steward.ipAddress];
    self.monitor.delegate = self;
    [self.monitor startMonitoringEvents];
    NSLog(@"Started to monitor events");
}

- (void)stopMonitoringEvents {
    [self.monitor stopMonitoringEvents];

}

- (void)performWithDevice:(NSString *)device andRequest:(NSString *)request andParameters:(NSString *)parameters {
    self.perform  = [[Perform alloc] initWithAddress:self.steward.ipAddress];
    self.perform.delegate = self;
    [self.perform performWithDevice:device andRequest:request andParameters:parameters];
}

- (NSString *)generateTOTP {
    
    if ( self.authURL ) {
        NSArray *array = [self.authURL.absoluteString componentsSeparatedByString:@"="];
        self.secret = array[1];
        NSLog(@"URL to String, secret = %@", self.secret);
    }
    
    NSData * secret = [OTPAuthURL base32Decode:self.secret ];
    TOTPGenerator *generator  = [[TOTPGenerator alloc] initWithSecret:secret algorithm:kOTPGeneratorSHA1Algorithm digits:[TOTPGenerator defaultDigits] period:[TOTPGenerator defaultPeriod]];
    
    return [generator generateOTP];

}

- (NSString *)generateTOTPwithSecret:(NSString *)secret {
    self.secret = secret;
    NSString *totp = [self generateTOTP];
    
    return totp;
}

#pragma mark - Overridden Getter and Setter Methods

- (NSURL *)authURL {
    return authURL;
}

- (void)setAuthURL:(NSURL *)url {
    NSLog(@"Setting authURL to %@", url);
    authURL = url;
    
    NSArray *array = [url.absoluteString componentsSeparatedByString:@"="];
    self.secret = array[1];
    NSLog(@"URL to String, secret = %@", self.secret);
    
    array = [url.absoluteString componentsSeparatedByString:@"?"];
    NSString *pre = array[0];
    array = [pre componentsSeparatedByString:@"/"];
    NSString *user = [NSString stringWithFormat:@"%@/%@",array[5],array[6]];
    NSLog(@"URL to String, clientID = %@", user);
    self.clientID = user;
    
}


// -----------------------------------------------------------------------------
#pragma mark - Steward Delegate Methods

- (void)stewardFoundWithAddress:(NSString *)ip {
    NSLog(@"Found steward with IP address of %@", ip);
    if ( [self.delegate respondsToSelector:@selector(stewardFoundWithAddress:)] ) {
        [self.delegate stewardFoundWithAddress:ip];
    }
    
}

- (void)stewardNotFoundWithError:(NSError *)error {
    if ( [self.delegate respondsToSelector:@selector(stewardNotFoundWithError:)] ) {
        [self.delegate stewardNotFoundWithError:error];
    }
    
}

// -----------------------------------------------------------------------------
#pragma mark - Monitor Delegate Methods

- (void)receivedEventMessage:(NSString *)message {
    if ( [self.delegate respondsToSelector:@selector(receivedEventMessage:)] ) {
        [self.delegate receivedEventMessage:(NSString *)message];
    }
}

// -----------------------------------------------------------------------------
#pragma mark - Devices Delegate Methods

- (void)receivedDeviceList:(NSString *)message {
    if ( [self.delegate respondsToSelector:@selector(receivedDeviceList:)] ) {
        [self.delegate receivedDeviceList:(NSString *)message];
    }
}

- (void)receivedPerformResponse:(NSString *)message {
    if ( [self.delegate respondsToSelector:@selector(receivedPerformResponse:)] ) {
        [self.delegate receivedPerformResponse:(NSString *)message];
    }
}

// -----------------------------------------------------------------------------
#pragma mark - Class Methods

+ (NSString *)version {
    return LIBRARY_VERSION;
}

@end
