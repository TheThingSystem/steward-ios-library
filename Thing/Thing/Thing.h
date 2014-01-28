//
//  Thing.h
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

#import <Foundation/Foundation.h>

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netdb.h>

#define LIBRARY_VERSION @"0.1.2"
#define ISO_TIMEZONE_UTC_FORMAT @"Z"
#define ISO_TIMEZONE_OFFSET_FORMAT @"+%02d%02d"

// -----------------------------------------------------------------------------
#pragma mark - Steward

@protocol StewardDelegate <NSObject>

@required
- (void)foundStewardWithAddress:(NSString *)ip;

@optional
- (void)stewardNotFoundWithError:(NSError *)error;

@end

@interface Steward : NSObject <NSCoding, NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (nonatomic, weak) id <StewardDelegate> delegate;
@property (nonatomic, strong) NSNetServiceBrowser *browser;
@property (nonatomic, strong) NSNetService *service;
@property (nonatomic, strong) NSString *ipAddress;

- (void)findSteward;

@end

// -----------------------------------------------------------------------------
#pragma mark - Device

@interface Device : NSObject <NSCoding>

@property (nonatomic, strong) NSString *device;

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *maker;
@property (nonatomic, strong) NSString *serial;
@property (nonatomic, strong) NSString *udn;
@property (nonatomic, strong) NSDictionary *properties;

- (id)initWithDevice:(NSString *)name;

@end


// -----------------------------------------------------------------------------
#pragma mark - Thing

@protocol ThingDelegate <NSObject>

@optional
- (void)stewardNotFoundWithError:(NSError *)error;

@end

@interface Thing : NSObject <StewardDelegate>

@property (nonatomic, strong) Steward *steward;
@property (nonatomic, strong) Device *device;
@property (nonatomic) BOOL debug;
@property (nonatomic) int requestCounter;

- (void)findSteward;
- (void)dispatchWithInformation:(NSDictionary *)info;

- (void)archiveDevice;
- (void)restoreDevice;

+ (Thing *)sharedThing;
+ (NSString *)version;

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

