//
//  Util.m
//
//  Created by Alasdair Allan on 06/12/2010.
//  Copyright (c) 2010 Babilim Light Industries. All rights reserved.
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

#import <SystemConfiguration/SystemConfiguration.h>

#import "Client.h"

@implementation Util


+ (NSString*)uniqueID {
    NSString* uniqueIdentifier = nil;
    if( [UIDevice instancesRespondToSelector:@selector(identifierForVendor)] ) {
        // iOS 6+
        uniqueIdentifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    } else {
        // before iOS 6, so just generate an identifier and store it
        uniqueIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:@"identiferForVendor"];
        if( !uniqueIdentifier ) {
            CFUUIDRef uuid = CFUUIDCreate(NULL);
            uniqueIdentifier = ( NSString*)CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
            CFRelease(uuid);
            [[NSUserDefaults standardUserDefaults] setObject:uniqueIdentifier forKey:@"identifierForVendor"];
        }
    }
    return uniqueIdentifier;
}//

// From: http://www.cocoadev.com/index.pl?BaseSixtyFour
+ (NSString*)base64forData:(NSData*)theData {
    const uint8_t* input = (const uint8_t*)[theData bytes];
    NSInteger length = [theData length];
    
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    
    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;
    
    NSInteger i;
    for (i=0; i < length; i += 3) {
        NSInteger value = 0;
        NSInteger j;
        for (j = i; j < (i + 3); j++) {
            value <<= 8;
            
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
        
        NSInteger theIndex = (i / 3) * 4;
        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }
    
    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}

+(NSString *)getIPAddress {
	NSString *address = @"error";
	struct ifaddrs *interfaces = NULL;
	struct ifaddrs *temp_addr = NULL;
	int success = 0;
	
	// retrieve the current interfaces - returns 0 on success
	success = getifaddrs(&interfaces);
	if (success == 0)
	{
		// Loop through linked list of interfaces
		temp_addr = interfaces;
		while(temp_addr != NULL)
		{
			if(temp_addr->ifa_addr->sa_family == AF_INET)
			{
				
				if ( [Client sharedClient].debug ) {
					NSLog(@"Util: getIPAddress: ifa_name = %@", [NSString stringWithUTF8String:temp_addr->ifa_name] );
				}
				
				// Check if interface is en0 which is the wifi connection on the iPhone
				if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"] ||
				   [[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en1"] ) {
					// Get NSString from C String
					address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
					if ( [Client sharedClient].debug ) {
						NSLog(@"Util: getIPAddress: IP (via WiFi) = %@", address );
					}
					break;
				} else if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"pdp_ip0"]) {
					// Get NSString from C String
					address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
					if ( [Client sharedClient].debug ) {
						NSLog(@"Util: getIPAddress: IP (via WWAN) = %@", address );
					}
					break;
				}
			}
			
			temp_addr = temp_addr->ifa_next;
		}
	}
	
	// Free memory
	freeifaddrs(interfaces);
	
	return address;
}

+(NSString *)connectionType {
	NSString *type = @"error";
	
	// Create zero addy
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
    
	// Recover reachability flags
	SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *) &zeroAddress);
	SCNetworkReachabilityFlags flags;
    
	BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
	CFRelease(defaultRouteReachability);
    
	if (!didRetrieveFlags) {
		if ( [Client sharedClient].debug ) {
			NSLog(@"Util: connectionType: Could not recover network reachability flags");
		}
		return type;
	}
	
	if ( [Client sharedClient].debug ) {
		NSLog(@"Util: connectionType: %c%c %c%c%c%c%c%c%c\n",
              (flags & kSCNetworkReachabilityFlagsIsWWAN)				? 'W' : '-',
              (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
              (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
              (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
              (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
              (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
              (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
              (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
              (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-'
              );
	}
	
	BOOL isReachable = ((flags & kSCNetworkFlagsReachable) != 0);
	//BOOL needsConnection = ((flags & kSCNetworkFlagsConnectionRequired) != 0);
	BOOL isWWAN = (( flags & kSCNetworkReachabilityFlagsIsWWAN ) != 0);
	
	if( isReachable && isWWAN ) {
		type = @"wwan";
		if ( [Client sharedClient].debug ) {
			NSLog( @"Util: connectionType: Reachable via WWAN" );
		}
	} else if ( isReachable && !isWWAN ) {
		type = @"wifi";
		if ( [Client sharedClient].debug ) {
			NSLog( @"Util: connectionType: Reachable via WiFi" );
		}
	} else {
		type = @"other";
		if ( [Client sharedClient].debug ) {
			NSLog( @"Util: connectionType: Needs connection" );
		}
	}
	
	return type;
}

+(NSString *)stringFromDate:(NSDate *)theDate {
    
	// Returns ISO8601 formatted string for a passed NSDate
	static NSDateFormatter* formatter = nil;
	
    if (!formatter) {
        formatter = [[NSDateFormatter alloc] init];
		
        NSTimeZone *timeZone = [NSTimeZone localTimeZone];
        int offset = (int)[timeZone secondsFromGMT];
		
        NSMutableString *strFormat = [NSMutableString stringWithString:@"yyyy-MM-dd'T'HH:mm:ss"];
        offset /= 60; //bring down to minutes
        if (offset == 0)
            [strFormat appendString:ISO_TIMEZONE_UTC_FORMAT];
        else
            [strFormat appendFormat:ISO_TIMEZONE_OFFSET_FORMAT, offset / 60, offset % 60];
		
        //NSLog(@"Util: strFormat = %@", strFormat);
        
        [formatter setTimeStyle:NSDateFormatterFullStyle];
        [formatter setDateFormat:strFormat];
    }
    return[formatter stringFromDate:theDate];
}

+(NSDate *)dateFromString:(NSString *)theString {
    static NSDateFormatter* sISO8601 = nil;
    
	// Turn ISO8601 formatted string into an NSDate
	
    if (!sISO8601) {
        sISO8601 = [[NSDateFormatter alloc] init];
        [sISO8601 setTimeStyle:NSDateFormatterFullStyle];
        [sISO8601 setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    }
    if ([theString hasSuffix:@"Z"]) {
        theString = [theString substringToIndex:(theString.length-1)];
    }
	
    NSDate *d = [sISO8601 dateFromString:theString];
    return d;
	
}

+(NSString *)documentsDirectoryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ( [Client sharedClient].debug ) {
        NSLog( @"Util: documentsDirectoryPath: path = %@", [paths objectAtIndex:0] );
    }
    return [paths objectAtIndex:0];
} 

@end
