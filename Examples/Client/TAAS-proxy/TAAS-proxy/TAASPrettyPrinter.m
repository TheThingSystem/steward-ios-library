//
//  TAASPrettyPrinter.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 6/4/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASPrettyPrinter.h"
#import "ZFCardinalDirection.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
// static const int ddLogLevel = LOG_LEVEL_VERBOSE;


enum PPenum {
    kCelcius,
    kColor,
    kConditions,
    kDecibels,
    kDegrees,
    kIgnore,
    kKilometers,
    kLocation,
    kLux,
    kMeters,
    kMetersPerSecond,
    kMetersApprox,
    kMilliBars,
    kMilliMeters,
    kMilliMetersPerHour,
    kPcsPerLiter,
    kPPM,
    kPercentage,
    kTimestamp,
    kTrack,
    kWatts,
    kVolts,

    kDefault
};


@interface  TAASPrettyPrinter ()
@property (strong, nonatomic) NSDictionary    *enums;
@property (strong, nonatomic) NSDateFormatter *utcFormatter;
@end


@implementation  TAASPrettyPrinter

+ (TAASPrettyPrinter *)singleton {
    static TAASPrettyPrinter *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{ shared = [[TAASPrettyPrinter alloc] init]; });
    return shared;
}

- (id) init {
    if ((self = [super init])) {
        self.enums = @{ @"accuracy"        : @(kMetersApprox)
                      , @"airQuality"      : @(kPPM)
                      , @"altitude"        : @(kMeters)
                      , @"authorizeURL"    : @(kIgnore)
                      , @"battery"         : @(kVolts)
                      , @"batteryLevel"    : @(kPercentage)
                      , @"brightness"      : @(kPercentage)
                      , @"co"              : @(kPPM)
                      , @"co2"             : @(kPPM)
                      , @"concentration"   : @(kPcsPerLiter)
                      , @"conditions"      : @(kConditions)
                      , @"cycleTime"       : @(kIgnore)
                      , @"displayUnits"    : @(kIgnore)
                      , @"distance"        : @(kKilometers)
                      , @"email"           : @(kIgnore)
                      , @"exporting"       : @(kWatts)
                      , @"extTemperature"  : @(kCelcius)
                      , @"fanSpeed"        : @(kPercentage)
                      , @"flow"            : @(kPPM)
                      , @"forecasts"       : @(kIgnore)
                      , @"generating"      : @(kWatts)
                      , @"goalTemperature" : @(kCelcius)
                      , @"hcho"            : @(kPPM)
                      , @"heading"         : @(kDegrees)
                      , @"humidity"        : @(kPercentage)
                      , @"identity"        : @(kIgnore)
                      , @"intTemperature"  : @(kCelcius)
                      , @"lastSample"      : @(kTimestamp)
                      , @"lastupdated"     : @(kTimestamp)
                      , @"light"           : @(kLux)
                      , @"location"        : @(kLocation)
                      , @"locations"       : @(kIgnore)
                      , @"moisture"        : @(kMilliBars)
                      , @"monitoring"      : @(kIgnore)
                      , @"nextSample"      : @(kTimestamp)
                      , @"no2"             : @(kPPM)
                      , @"noise"           : @(kDecibels)
                      , @"odometer"        : @(kKilometers)
                      , @"pressure"        : @(kMilliBars)
                      , @"rainRate"        : @(kMilliMetersPerHour)
                      , @"rainTotal"       : @(kMilliMeters)
                      , @"range"           : @(kKilometers)
                      , @"rankings"        : @(kIgnore)
                      , @"remote"          : @(kIgnore)
                      , @"review"          : @(kIgnore)
                      , @"rssi"            : @(kDecibels)
                      , @"smoke"           : @(kPPM)
                      , @"station"         : @(kIgnore)
                      , @"temperature"     : @(kCelcius)
                      , @"track"           : @(kTrack)
                      , @"velocity"        : @(kMetersPerSecond)
                      , @"version"         : @(kIgnore)
                      , @"visibility"      : @(kKilometers)
                      , @"volume"          : @(kPercentage)
                      , @"waterVolume"     : @(kPercentage)
                      , @"windAverage"     : @(kMetersPerSecond)
                      , @"windDirection"   : @(kDegrees)
                      , @"windGust"        : @(kMetersPerSecond)
                      , @"windchill"       : @(kCelcius)

/* TODO:
                      , @"color"           : @(kColor)

                        dial last value
                      , @"currentUsage"
                      , @"dailyUsage"
                      , @"actor"
                      , @"property" -> lastValue
                      , @"gauges"
                      , @"plugs"
                      , @"sensors"
 */

                      };
        self.utcFormatter = [[NSDateFormatter alloc] init];
        [self.utcFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.zzz'Z'"];
        [self.utcFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    }
    return self;
}

- (NSString *)infoPP:(NSDictionary *)info
    withDisplayUnits:(BOOL)customaryP {
    NSMutableDictionary *state = [[NSMutableDictionary alloc] initWithCapacity:info.count];

    [info enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        value = [self normalize:value forKey:key withDisplayUnits:customaryP];
        if (value != nil) [state setObject:value forKey:key];
    }];

    return (state.count > 0) ? [self valuesPP:state] : @"";
};

-  (void)normalize:(NSMutableDictionary *)props
  withDisplayUnits:(BOOL)customaryP {
    [props enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        value = [self normalize:value forKey:key withDisplayUnits:customaryP];
        if (value != nil) [props setObject:value forKey:key];
    }];
}

-  (id)normalize:(id)value
          forKey:(NSString *)key
withDisplayUnits:(BOOL)customaryP {
    if (value == nil) return nil;
    if (([value isKindOfClass:[NSString class]]) && ([value isEqualToString:@"********"])) return nil;

    NSNumber *nType = [self.enums objectForKey:key];
    int iType = (nType != nil) ? [nType intValue] : kDefault;

    long vlong;
    NSArray *varray;
    NSDate *vdate;
    NSNumber *vnumber;
    NSMutableDictionary *vdict;
    NSString *vstring;
    ZFCardinalDirection *vcardinal;
    switch (iType) {
        case kCelcius:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            if (customaryP) vlong = ((vlong * 9) / 5) + 32;
            return [NSString stringWithFormat:@"%ld%@", vlong, customaryP ? @"\u2109" : @"\u2103"];

        case kConditions:
            if (![value isKindOfClass:[NSDictionary class]]) break;
            vdict = [value mutableCopy];
            [vdict removeObjectForKey:@"code"];
            [self normalize:vdict withDisplayUnits:customaryP];
// TODO: make it nested...
            return vdict;

        case kDecibels:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            return [NSString stringWithFormat:@"%ld\u33c8", vlong];

        case kDegrees:
                   if ([value isKindOfClass:[NSString class]]) {
                vnumber = [NSNumber numberWithDouble:[value doubleValue]];
            } else if (![value isKindOfClass:[NSNumber class]]) break;
            else vnumber = value;
            vcardinal = [[ZFCardinalDirection alloc] initWithCompassHeadingInDegrees:vnumber];
            if (vcardinal == nil) return [NSString stringWithFormat:@"%ld\u00b0", [vnumber longValue]];
            return [vcardinal headingAbbreviation];

        case kIgnore:
          return nil;

        case kKilometers:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            if (customaryP) vlong *= 0.621371;
            return [NSString stringWithFormat:@"%ld%@", vlong, customaryP ? @" miles" : @"km"];

        case kLocation:
            if (![value isKindOfClass:[NSArray class]]) break;
            varray = value;
            if (varray.count >= 2) {
                NSString *latitude  = [self decimal2sexagesimal:varray[0]
                                                withNorthOrEast:@"N"
                                                 andSouthOrWest:@"S"],
                         *longitude = [self decimal2sexagesimal:varray[1]
                                                withNorthOrEast:@"E"
                                                 andSouthOrWest:@"W"];
              if ((latitude != nil) || (longitude != nil)) {
                  vstring = [NSString stringWithFormat:@"%@ %@", latitude, longitude];
                  if (varray.count >= 3) {
                    vstring = [vstring stringByAppendingFormat:@" %@",
                                             [self normalize:varray[2]
                                                      forKey:@"altitude"
                                            withDisplayUnits:customaryP]];
                  }
                  return vstring;
              }
            }
            return [NSString stringWithFormat:@"(%@)", [value componentsJoinedByString:@", "]];

        case kLux:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            return [NSString stringWithFormat:@"%ld\u33d3", vlong];

        case kMeters:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            if (customaryP) vlong *= 3.28084;
            return [NSString stringWithFormat:@"%ld%@", vlong, customaryP ? @"ft" : @"m"];

        case kMetersApprox:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            if (customaryP) vlong *= 3.28084;
            return [NSString stringWithFormat:@"\u00b1%ld%@", vlong, customaryP ? @" feet" : @"m"];

         case kMetersPerSecond:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            if (customaryP) vlong *= 2.23694;
            return [NSString stringWithFormat:@"%ld%@", vlong, customaryP ? @" mph" : @"m/s"];

        case kMilliBars:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            return [NSString stringWithFormat:@"%ld mbars", vlong];

        case kMilliMeters:
        case kMilliMetersPerHour:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            if (customaryP) vlong *= 0.0393701;
            return [NSString stringWithFormat:@"%ld%@", vlong,
                             iType == (kMilliMeters) ? (customaryP ? @" inches"      : @"mm")
                                                     : (customaryP ? @" inches/hour" : @"mm/h")];

        case kPPM:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            return [NSString stringWithFormat:@"%ld ppm", vlong];

        case kPcsPerLiter:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            return [NSString stringWithFormat:@"%ld pcs/liter", vlong];

        case kPercentage:
// TODO: handle array case as well
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            return [NSString stringWithFormat:@"%ld%%", vlong];

        case kTimestamp:
                   if ([value isKindOfClass:[NSDate class]]) vdate = value;
              else if ([value isKindOfClass:[NSString class]]) {
                vdate = [self.utcFormatter dateFromString:value];
            } else if (![value isKindOfClass:[NSNumber class]]) break;
            else vdate = [NSDate dateWithTimeIntervalSince1970:([value doubleValue] / 1000)];
            if (vdate == nil) break;
            return [MHPrettyDate shortPrettyDateWithDate:vdate];

        case kTrack:
// TODO: make it nested...
            if (![value isKindOfClass:[NSDictionary class]]) break;
            vdict = [value mutableCopy];
            [vdict removeObjectForKey:@"albumArtURI"];
            vstring = [self milliseconds:[vdict objectForKey:@"duration"]];
            if (vstring != nil) [vdict setObject:vstring forKey:@"duration"];
            vstring = [self milliseconds:[vdict objectForKey:@"position"]];
            if (vstring != nil) [vdict setObject:vstring forKey:@"position"];
            return vdict;

        case kVolts:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            return [NSString stringWithFormat:@"%ld volts", vlong];

        case kWatts:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            return [NSString stringWithFormat:@"%ld watts", vlong];

        default:
            break;
    }

    return value;
}

- (NSString *)decimal2sexagesimal:(NSNumber *)value
                   withNorthOrEast:(NSString *)northOrEast
                   andSouthOrWest:(NSString *)southOrWest {
    if (value == nil) return nil;

    if ((![value isKindOfClass:[NSNumber class]]) && (![value isKindOfClass:[NSString class]]))return nil;
    double dd = [value doubleValue];
    NSString *direction = northOrEast;
    if (dd < 0) {
        dd = -dd;
        direction = southOrWest;
    }

    double degrees = floor(dd);
    dd = (dd - degrees) * 60;

    double minutes = floor(dd);
    dd = (dd - minutes) * 60;

    double seconds = round(dd);

    return [NSString stringWithFormat:@"%.0f\u00b0%02.0f\u2032%02.0f\u2033%@",
                     degrees, minutes, seconds, direction];
}


- (NSString *)milliseconds:(NSNumber *)value {
    if ((value == nil) || (![value isKindOfClass:[NSNumber class]])) return nil;

    long vlong = [value longValue];

    int ms = vlong % 1000;
    vlong = vlong / 1000;
    if (vlong == 0) return [NSString stringWithFormat:@"0.%03d secs", ms];
    NSString *suffix = (ms != 0) ? [NSString stringWithFormat:@".%03d", ms] : @"";

    int secs = vlong % 60;
    vlong = vlong / 60;
    if (vlong == 0) return [NSString stringWithFormat:@"%d%@", secs, suffix];

    int mins = vlong % 60;
    vlong = vlong / 60;
    if (vlong == 0) return [NSString stringWithFormat:@"%d:%d%@", mins, secs, suffix];

    int hours = vlong % 24;
    vlong = vlong / 24;
    if (vlong == 0) return [NSString stringWithFormat:@"%d:%d:%d%@", hours, mins, secs, suffix];

    return [NSString stringWithFormat:@"%ld:%d:%d:%d%@", vlong, hours, mins, secs, suffix];
}

- (NSString *)valuesPP:(id)value {
    NSMutableString *result = [[NSMutableString alloc] init];

    if ([value isKindOfClass:[NSDictionary class]]) {
        [value enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            NSString *string = [self valuePP:value];
            if (string == nil) return;
            if ((string.length > 36) && ([key isEqualToString:@"body"])) return;

            char keystring[20];
            snprintf(keystring, sizeof keystring, "%s:", (const char *)[key UTF8String]);
            if (result.length > 0) [result appendString:@"\n"];
            [result appendFormat:@"%-16.16s %@", keystring, value];
        }];

        return result;
    }

    if ([value isKindOfClass:[NSDictionary class]]) {
        [value enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
            NSString *string = [self valuePP:value];
            if (string == nil) return;

            char keystring[20];
            snprintf(keystring, sizeof keystring, "%lu:", (unsigned long) idx);
            if (result.length > 0) [result appendString:@"\n"];
            [result appendFormat:@"%-3.3s %@", keystring, value];
       }];

        return result;
    }

    return [self valuePP:value];
}

- (NSString *)dictionaryPP:(NSDictionary *)dict {
    NSMutableString *result = [[NSMutableString alloc] init];

    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        NSString *string = [self valuePP:value];
        if (string != nil) {
            if ((string.length > 36) && ([key isEqualToString:@"body"])) return;
            [result appendFormat:((result.length > 0) ? @", %@:%@" : @"{%@:%@"), key, string];
        }
    }];
    if (result.length == 0) return nil;
    [result appendString:@"}"];

    return result;
}

- (NSString *)arrayPP:(NSArray *)array {
    NSMutableString *result = [[NSMutableString alloc] init];

    [array enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
        NSString *string = [self valuePP:value];
        if (string != nil) [result appendFormat:((result.length > 0) ? @", %@" : @"[%@"), string];
    }];
    if (result.length == 0) return nil;
    [result appendString:@"]"];

    return result;
}

- (NSString *)valuePP:(id)value {
    if ((value == nil) || ([value isKindOfClass:[NSNull class]])) return nil;

    if ([value isKindOfClass:[NSDictionary class]]) return [self dictionaryPP:value];
    if ([value isKindOfClass:[NSArray class]]) return [self arrayPP:value];
    if (![value isKindOfClass:[NSString class]]) return [NSString stringWithFormat:@"%@", value];

    NSError *error = nil;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&error];
    return (dictionary ? [self dictionaryPP:dictionary] : value);
}

@end


@implementation MHPrettyDate (TAAS)

+ (NSString *)shortPrettyDateWithDate:(NSDate *)date {
    if (date == nil) return nil;

    NSInteger seconds = [date timeIntervalSinceNow];
    if (seconds <= 0) return [MHPrettyDate shortPrettyDateFromDate:date];

    date = [NSDate dateWithTimeIntervalSinceNow:(-seconds)];
    NSString *value = [MHPrettyDate shortPrettyDateFromDate:date];
    return [NSString stringWithFormat:@"in %@", value];
}

+ (NSString *)shortPrettyDateFromDate:(NSDate *)date {
    if (date == nil) return nil;

    NSInteger seconds = [date timeIntervalSinceNow];
    if (seconds <= -60) {
        return [MHPrettyDate prettyDateFromDate:date withFormat:MHPrettyDateShortRelativeTime];
    }
    if (seconds ==  0) return @"now";
    return [NSString stringWithFormat:@"%ld%@", (long)-seconds,
                     NSLocalizedStringFromTable(@"s", @"MHPrettyDate", nil)];
}
@end
