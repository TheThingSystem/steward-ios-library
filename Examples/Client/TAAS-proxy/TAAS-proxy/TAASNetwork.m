//
//  TAASNetwork.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 8/11/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASNetwork.h"
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_types.h>
#include <net/route.h>
#include <net/if_dl.h>
#include <net/ethernet.h>
#include <netinet/if_ether.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <strings.h>
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
// static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@implementation TAASNetwork

+ (TAASNetwork *)singleton {
    static TAASNetwork *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{ shared = [[TAASNetwork alloc] init]; });
    return shared;
}


#define ROUNDUP(a) \
        ((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))

- (NSDictionary *)routingInfo {
    int mib[6];
    size_t needed;
    char *lim, *buf, *next;

    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    mib[0] = CTL_NET;
    mib[1] = PF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_INET;
    mib[4] = NET_RT_FLAGS;
    mib[5] = RTF_GATEWAY;
    needed = fetch(mib, sizeof mib / sizeof mib[0], "routing table", &buf);

    lim = buf + needed;
    struct rt_msghdr *rtm = NULL;
    for (next = buf; next < lim; next += rtm->rtm_msglen) {
        rtm = (struct rt_msghdr *)next;
        struct sockaddr *sa = (struct sockaddr *)(rtm + 1);
        struct sockaddr *rtax[RTAX_MAX];

        bzero (rtax, sizeof rtax);
        int i;
        for (i = 0; i < RTAX_MAX; i++) {
          if (!(rtm->rtm_addrs & (1 << i))) continue;
            rtax[i] = sa;
            sa = (struct sockaddr *)((char *)sa + ROUNDUP(sa->sa_len));
        }

        struct sockaddr_in *sin = (struct sockaddr_in *)rtax[RTAX_DST];
        if (((rtm->rtm_addrs & (RTA_DST | RTA_GATEWAY)) == (RTA_DST | RTA_GATEWAY))
                && (rtax[RTAX_DST]->sa_family == AF_INET)
                && (sin->sin_addr.s_addr == 0)
                && (rtax[RTAX_GATEWAY]->sa_family == AF_INET)) {
            sin = (struct sockaddr_in *)rtax[RTAX_GATEWAY];
            NSString *gw = [NSString stringWithCString:inet_ntoa(sin->sin_addr) encoding:NSASCIIStringEncoding];

            [result setObject:@{ @"destination" : @"default"
                               , @"gateway"     : gw
                               }
                       forKey:gw];
        }
    }
    free(buf);

    mib[0] = CTL_NET;
    mib[1] = PF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_INET;
    mib[4] = NET_RT_FLAGS;
    mib[5] = RTF_LLINFO;
    needed = fetch(mib, sizeof mib / sizeof mib[0], "routing table", &buf);
    lim = buf + needed;
    rtm = NULL;
    for (next = buf; next < lim; next += rtm->rtm_msglen) {
        rtm = (struct rt_msghdr *)next;
        struct sockaddr_inarp *sin = (struct sockaddr_inarp *)(rtm + 1);
        struct sockaddr_dl *sdl = (struct sockaddr_dl *)(sin + 1);
        if (sdl->sdl_alen != 6) continue;

        NSString *dst = [NSString stringWithCString:inet_ntoa(sin->sin_addr) encoding:NSASCIIStringEncoding];
        NSMutableDictionary *entry = [result objectForKey:dst];
        if (entry == nil) continue;

        char *cp = LLADDR(sdl);
        NSString *mac = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                                  cp[0] & 0xff, cp[1] & 0xff, cp[2] & 0xff, cp[3] & 0xff, cp[4] & 0xff, cp[5] & 0xff];
        entry = [entry mutableCopy];
        [entry setObject:mac forKey:@"mac"];
        [result setObject:entry forKey:dst];
    }
    free(buf);

    return result;
}

static size_t fetch(int *mib, u_int mibsize, char *tablename, char **buf) {
    size_t needed;

    *buf = NULL;
    needed = 0;
    if ((sysctl(mib, mibsize, NULL, &needed, NULL, 0) >= 0)
            && ((*buf = malloc(needed)) != NULL)
            && (sysctl(mib, mibsize, *buf, &needed, NULL, 0) >= 0)) {
        return needed;
    }
    if (*buf != NULL) free(*buf);

    NSLog(@"unable to %s %s", needed == 0 ? "calculate size of" : *buf == NULL ? "allocate buffer for" : "retrieve",
          tablename);
    return 0;
}

@end
