//
//  TAASGoogleResponse.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 6/31/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASGoogleResponse.h"
#import "AppDelegate.h"
#import "RequestUtils.h"
#import "MDCDamerauLevenshtein.h"
#import "HTTPLogging.h"


// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE;


@implementation TAASGoogleResponse

// /search?q=trigger+hello+world&ie=UTF-8&oe=UTF-8&hl=en&client=safari

- (id)initWithPath:(NSString *)path {
    NSDictionary *parameters = [path URLQueryParameters];
    NSString *q = [parameters objectForKey:@"q"];
    NSRange range = [q rangeOfString:@"trigger " options:NSAnchoredSearch];
    if (range.location != NSNotFound) q = [q substringFromIndex:(range.location + range.length)];

    AppDelegate *appDelegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    RootController *rootController = appDelegate.rootController;
    if (rootController.commands == nil) return nil;

    NSMutableArray *possibles = [NSMutableArray arrayWithCapacity:5];
    NSMutableString *matches = [NSMutableString stringWithCapacity:1024];
    NSUInteger minimum = 2, *minimumP = &minimum;
    NSMutableString *suffix = [NSMutableString stringWithCapacity:1024];
    [suffix setString:@"and nothing matched. Sorry!"];
    NSString *prefix = [NSString stringWithFormat:@"You asked Siri: \"%@\"", q];
    [rootController.commands enumerateKeysAndObjectsUsingBlock:^(id key, NSDictionary *value,
                                                                 BOOL *stop) {
        NSUInteger distance;
        switch (distance = [q mdc_damerauLevenshteinDistanceTo:key]) {
            case 0:
                *minimumP = distance;
                *stop = true;

                [matches setString:@""];
                [suffix setString:@": success!"];
                [possibles removeAllObjects];
                [possibles addObject:value];
                return;

            case 1:
            case 2:
                if (distance > minimum) return;
                if (distance < minimum) {
                    *minimumP = distance;
                    [matches setString:@""];
                    [possibles removeAllObjects];
                }

                if (matches.length == 0) {
                    [matches setString:@", but no commands where matched. Possibilities are:<ul>"];
                }
                [matches appendFormat:@"<li>%@</li>", key];
                [possibles addObject:value];
                break;

            default:
                return;
        }
    }];

    if (possibles.count == 1) {
        NSDictionary *script = [possibles objectAtIndex:0];
        [rootController scripter:script];
        if (minimum > 0) {
            [suffix setString:@""];
            [suffix appendFormat:@". Best match was \"%@\" at distance %lu.",
                    [script objectForKey:@"name"], (unsigned long)minimum];
        }
    } else if (matches.length > 0) {
        [matches appendFormat:@"</ul>at distance %lu.", (unsigned long)minimum];
        suffix = matches;
    }

    NSData *body = [[NSString stringWithFormat:@"<head><head><title>TAAS-proxy</title></head><body>\
%@%@\
</body></html>\
",
                              prefix, suffix] dataUsingEncoding:NSUTF8StringEncoding];

    if ((self = [super initWithData:body])) {
        HTTPLogInfo(@"%@[%p]: initWithPath: %@", THIS_FILE, self, path);
    }
    return self;
}

@end
