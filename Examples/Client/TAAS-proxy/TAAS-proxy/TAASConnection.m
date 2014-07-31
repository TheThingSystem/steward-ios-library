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
#import "TAASTunnelResponse.h"
#import "TAASWebSocket.h"
#import "FXKeychain.h"
#import "GCDAsyncSocket.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface TAASConnection ()

@property (strong, nonatomic) TAASProxyResponse         *response;
@property (strong, nonatomic) TAASTunnelResponse        *tunnel;
@property (strong, nonatomic) TAASWebSocket             *ws;

@end


@implementation TAASConnection

- (BOOL)supportsMethod:(NSString *)method
                atPath:(NSString *)path {
// NB: ideally, should only get here if proxy.pac is properly written; however, be fail-friendly

    return (([method isEqualToString:@"CONNECT"]) || ([super supportsMethod:method atPath:path]));
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method
                                              URI:(NSString *)path {
    NSString *serviceURI;

    if ([method isEqualToString:@"CONNECT"]) {
        self.tunnel = [[TAASTunnelResponse alloc] initWithPath:path
                                                    fromSocket:asyncSocket
                                                    forConnection:self];
        return self.tunnel;
    }

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
    serviceURI = [service serviceURI:path];
    if (serviceURI == nil) {
        return [[TAASErrorResponse alloc] initWithStatusCode:503
                                                     andBody:[self dataForBody:@"503 Not Connected"]];
    }

    NSRange range = [path rangeOfString:@"/search?q="];
    if (range.location != NSNotFound) {
        DDLogVerbose(@"interpret %@", [path substringFromIndex:(range.location + range.length)]);
        return [[TAASErrorResponse alloc] initWithStatusCode:500
                                                     andBody:[self dataForBody:@"not implemented"]];
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


@implementation TAASSecureConnection

static NSArray    *keysAndCerts  = nil;
static CFArrayRef  importedItems = NULL;

#define kKeysAndCerts    @"_keysAndCerts"

+ (BOOL)hasKeys:(NSString *)documentCerts {
    if (keysAndCerts != nil) return YES;

    BOOL foundP = NO;
    NSData *data1 = nil;
    NSData *data2 = nil;
    NSError *error;
    NSString *path1;

    if (documentCerts != nil) {
        // openssl pkcs12 -export -name TAAS-proxy -in proxy.pem -out proxy.p12 -passout 'pass:'
        path1 = [documentCerts stringByAppendingPathComponent:@"proxy.p12"];
        BOOL isDir = NO;
        if (([[NSFileManager defaultManager] fileExistsAtPath:path1 isDirectory:&isDir]) && (!isDir)) {
            error = nil;
            data1 = [NSData dataWithContentsOfFile:path1 options:0 error:&error];
            foundP = data1 != nil;
            if (!foundP) DDLogError(@"read %@: %@", path1, error);
        }

        // openssl x509 -inform pem -outform der -in proxy.crt -out proxy.cer
        NSString *path2 = [documentCerts stringByAppendingPathComponent:@"proxy.cer"];
        isDir = NO;
        if (([[NSFileManager defaultManager] fileExistsAtPath:path2 isDirectory:&isDir]) && (!isDir)) {
            error = nil;
            data2 = [NSData dataWithContentsOfFile:path2 options:0 error:&error];
            if (data2 == nil) DDLogError(@"read %@: %@", path2, error);
        }
    }

    FXKeychain *keyChain = [FXKeychain defaultKeychain];
    NSArray *keyChainData = (keyChain != nil) ? [keyChain objectForKey:kKeysAndCerts] : nil;
    if (data1 == nil) {
        if ((keyChainData == nil) || (keyChainData.count < 1)) return NO;
        data1 = [keyChainData objectAtIndex:0];
    }
    if (data2 == nil) {
        if ((keyChainData == nil) || (keyChainData.count < 2)) return NO;
        data2 = [keyChainData objectAtIndex:1];
    }
    if ((data1 == nil) || (data2 == nil)) return NO;

    NSString  *name = @"TAAS-Proxy";
    NSData *identityTag = [[NSData alloc] initWithBytes:(const void*)[name UTF8String] length:[name length]];
    NSMutableDictionary *pkcsOptions = [[NSMutableDictionary alloc] init];
    [pkcsOptions setObject:@"" forKey:(__bridge id<NSCopying>)(kSecImportExportPassphrase)];

    OSStatus status = SecPKCS12Import((__bridge CFDataRef)data1, (__bridge CFDictionaryRef)pkcsOptions, &importedItems);
    if (status != noErr) {
        DDLogError(@"problem decoding pkcs12: OSStatus=%ld", (long)status);
        return NO;
    }

    SecIdentityRef identity = NULL;
    for (NSDictionary * itemDict in (__bridge id) importedItems) {
        identity = (__bridge SecIdentityRef) [itemDict objectForKey:(__bridge NSString *) kSecImportItemIdentity];
        NSMutableDictionary *namedIdentityAttr = [[NSMutableDictionary alloc] init];
        [namedIdentityAttr setObject:(__bridge id)identity forKey:(__bridge id)kSecValueRef];
        [namedIdentityAttr setObject:identityTag forKey:(__bridge id)kSecAttrLabel];
        status = SecItemAdd((__bridge CFDictionaryRef)(namedIdentityAttr), NULL);
        if (status == errSecDuplicateItem) status = noErr;
        if (status != noErr) break;
    }

    if (status != noErr) {
        DDLogError(@"problem adding identity: OSStatus=%ld", (long)status);
        return NO;
    }

    SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(data2));

    if (foundP) {
        [keyChain setObject:[NSArray arrayWithObjects:data1, data2, nil] forKey:kKeysAndCerts];

/*
        if (![[NSFileManager defaultManager] removeItemAtPath:path1 error:&error]) {
            DDLogError(@"delete %@: %@", path1, error);
        }
 */NSLog(@"delete %@", path1);
    }

    keysAndCerts = [NSArray arrayWithObjects:(__bridge id)identity, CFBridgingRelease(certificate), nil];
    return YES;
}


- (BOOL)isSecureServer {
    return YES;
}

- (NSArray *)sslIdentityAndCertificates {
    return keysAndCerts;
}

@end
