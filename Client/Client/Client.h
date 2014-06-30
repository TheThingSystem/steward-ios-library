//
//  Client.h
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

#import <Foundation/Foundation.h>

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netdb.h>

#import "SRWebSocket.h"

#define LIBRARY_VERSION @"0.4.2"
#define ISO_TIMEZONE_UTC_FORMAT @"Z"
#define ISO_TIMEZONE_OFFSET_FORMAT @"+%02d%02d"

// -----------------------------------------------------------------------------
#pragma mark - Steward

@protocol StewardDelegate <NSObject>

@required
- (void)stewardFoundWithAddress:(NSString *)ipAddress;

@optional
- (void)stewardNotFoundWithError:(NSError *)error;
- (void)stewardFoundAtService:(NSNetService *)service;
- (void)stewardDidStopSearching;
- (void)stewardNotSearchedWithErrorDict:(NSDictionary *)errorDict;
- (void)stewardNotResolvedWithErrorDict:(NSDictionary *)errorDict;

@end

@interface Steward : NSObject <NSCoding, NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (nonatomic, weak) id <StewardDelegate> delegate;

@property (nonatomic, strong) NSNetServiceBrowser *browser;
@property (nonatomic, strong) NSNetService *service;
@property (nonatomic, strong) NSString *ipAddress;

- (void)findSteward;

@end

// -----------------------------------------------------------------------------
#pragma mark - Monitor

@protocol MonitorDelegate <NSObject>

@required
- (void)receivedEventMessage:(NSString *)message;

@optional
- (void)startedMonitoring;
- (void)monitoringFailedWithError:(NSError *)error;
- (void)monitoringClosedWithCode:(NSInteger)code;

@end

@interface Monitor : NSObject <SRWebSocketDelegate>


@property (nonatomic, weak) id <MonitorDelegate> delegate;
@property (nonatomic, strong) SRWebSocket *webSocket;

- (id)initWithAddress:(NSString *)ipAddress;
- (id)initWithAddress:(NSString *)ipAddress andPort:(long)port andServiceType:(NSURLRequestNetworkServiceType)serviceType;
- (void)startMonitoringEvents;
- (void)stopMonitoringEvents;

@end


// -----------------------------------------------------------------------------
#pragma mark - Devices

@protocol DevicesDelegate <NSObject>

@required
- (void)receivedDeviceList:(NSString *)message;

@optional
- (void)startedListing;
- (void)listingFailedWithError:(NSError *)error;
- (void)listingClosedWithCode:(NSInteger)code;

@end

@interface Devices : NSObject <SRWebSocketDelegate>

@property (nonatomic, weak) id <DevicesDelegate> delegate;
@property (nonatomic, strong) SRWebSocket *webSocket;

@property (nonatomic) BOOL oneShotP;
@property (nonatomic) BOOL opened;


- (id)initWithAddress:(NSString *)ipAddress;
- (id)initWithAddress:(NSString *)ipAddress andPort:(long)port andOneShotP:(BOOL)oneShotP;
- (void)listAllDevices;
- (void)stopListingDevices;

@end

// -----------------------------------------------------------------------------
#pragma mark - Perform

@protocol PerformDelegate <NSObject>

@required
- (void)receivedPerformResponse:(NSString *)message;

@end

@interface Perform : NSObject <SRWebSocketDelegate>

@property (nonatomic, weak) id <PerformDelegate> delegate;
@property (nonatomic, strong) SRWebSocket *webSocket;

@property (nonatomic, strong) NSString *device;
@property (nonatomic, strong) NSString *request;
@property (nonatomic, strong) NSString *parameters;
@property (nonatomic) BOOL authenticate;
@property (nonatomic) BOOL opened;
@property (nonatomic) BOOL followup;


- (id)initWithAddress:(NSString *)ipAddress;
- (id)initWithAddress:(NSString *)ipAddress andPort:(long)port;
- (void)performWithDevice:(NSString *)device andRequest:(NSString *)request andParameters:(NSString *)parameters;

@end


// -----------------------------------------------------------------------------
#pragma mark - Client

@protocol ClientDelegate <NSObject>

@optional
- (void)stewardNotFoundWithError:(NSError *)error;
- (void)stewardDidStopSearching;
- (void)stewardNotSearchedWithErrorDict:(NSDictionary *)errorDict;
- (void)stewardNotResolvedWithErrorDict:(NSDictionary *)errorDict;
- (void)stewardFoundAtService:(NSNetService *)service;
- (void)stewardFoundWithAddress:(NSString *)ipAddress;
- (void)receivedEventMessage:(NSString *)message;
- (void)receivedDeviceList:(NSString *)message;
- (void)receivedPerformResponse:(NSString *)message;

@end

@interface Client : NSObject <StewardDelegate, MonitorDelegate, DevicesDelegate, PerformDelegate> {
    
    NSURL *authURL;
}

@property (nonatomic, weak) id <ClientDelegate> delegate;

@property (nonatomic, strong) Steward *steward;
@property (nonatomic, strong) Monitor *monitor;
@property (nonatomic, strong) Devices *devices;
@property (nonatomic, strong) Perform *perform;
@property (nonatomic) BOOL debug;
@property (nonatomic) int requestCounter;

@property (nonatomic) BOOL authenticate;
@property (nonatomic, strong) NSString *secret;
@property (nonatomic, strong) NSString *clientID;
@property (nonatomic, strong) NSString *stewardID;
@property (nonatomic, strong) NSURL *authURL;

+ (Client *)sharedClient;
+ (NSString *)version;

- (NSURL *)authURL;
- (void)setAuthURL:(NSURL *)url;

- (void)findSteward;

- (void)startMonitoringEvents;
- (void)stopMonitoringEvents;

- (void)availableDevices;

- (void)performWithDevice:(NSString *)device andRequest:(NSString *)request andParameters:(NSString *)parameters;

- (NSString *)generateTOTP;
- (NSString *)generateTOTPwithSecret:(NSString *)secret;


@end


// -----------------------------------------------------------------------------
#pragma mark - Utility

@interface Util : NSObject {
	
}

+ (NSString *)uniqueID;
+ (NSString *)base64forData:(NSData*)theData;
+ (NSString *)getIPAddress;
+ (NSString *)connectionType;
+ (NSString *)stringFromDate:(NSDate *)theDate;
+ (NSDate *)dateFromString:(NSString *)theString;
+ (NSString *)documentsDirectoryPath;

@end

@interface Util (Private)


@end


@interface NSNetService(ipAddresses)

- (NSArray *)ipAddresses;

@end


@interface NSURL(queryDictionary)

- (NSMutableDictionary *)queryDictionary;

@end
