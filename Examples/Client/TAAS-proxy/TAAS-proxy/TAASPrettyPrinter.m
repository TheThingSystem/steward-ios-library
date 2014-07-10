//
//  TAASPrettyPrinter.m
//  TAAS-proxy
//
//  Created by Marshall Rose on 6/4/14.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "TAASPrettyPrinter.h"
#import "AppDelegate.h"
#import "ZFCardinalDirection.h"
#import "DDLog.h"


// Log levels: off, error, warn, info, verbose
// Other flags: trace
// static const int ddLogLevel = LOG_LEVEL_VERBOSE;


#define kKeyLength    (12)

enum PPenum {
    kActor,
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
    kPhysical,
    kPPM,
    kPercentage,
    kTimestamp,
    kTrack,
    kWatts,
    kVolts,

    kDefault
};


@interface  TAASPrettyPrinter ()
@property (strong, nonatomic) NSDictionary    *alias;
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
        self.alias = @{ @"extTemperature"  : @"outsideTemp"
                      , @"goalTemperature" : @"goalTemp"
                      , @"intTemperature"  : @"insideTemp"
                      , @"temperature"     : @"temp"
                      };
        self.enums = @{ @"accuracy"        : @(kMetersApprox)
                      , @"actor"           : @(kActor)
                      , @"airQuality"      : @(kPPM)
                      , @"altitude"        : @(kMeters)
                      , @"authorizeURL"    : @(kIgnore)
                      , @"battery"         : @(kVolts)
                      , @"batteryLevel"    : @(kPercentage)
                      , @"brightness"      : @(kPercentage)
                      , @"co"              : @(kPPM)
                      , @"co2"             : @(kPPM)
                      , @"color"           : @(kColor)
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
                      , @"gauges"          : @(kActor)
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
                      , @"organization"    : @(kIgnore)
                      , @"physical"        : @(kPhysical)
                      , @"plugs"           : @(kActor)
                      , @"pressure"        : @(kMilliBars)
                      , @"rainRate"        : @(kMilliMetersPerHour)
                      , @"rainTotal"       : @(kMilliMeters)
                      , @"range"           : @(kKilometers)
                      , @"rankings"        : @(kActor)
                      , @"rankings"        : @(kIgnore)
                      , @"remote"          : @(kIgnore)
                      , @"review"          : @(kActor)
                      , @"review"          : @(kIgnore)
                      , @"rssi"            : @(kDecibels)
                      , @"sensors"         : @(kActor)
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
                      , @"currentUsage"
                      , @"dailyUsage"
 */

                      };
        self.utcFormatter = [[NSDateFormatter alloc] init];
        [self.utcFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.zzz'Z'"];
        [self.utcFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    }
    return self;
}

- (NSString *)infoPP:(NSDictionary *)info {
    NSMutableDictionary *state = [NSMutableDictionary dictionaryWithCapacity:info.count];

    [info enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        value = [self normalize:value forKey:key];
        if (value != nil) [state setObject:value forKey:key];
    }];

    return (state.count > 0) ? [self valuesPP:state] : @"";
};

-  (void)normalize:(NSMutableDictionary *)props {
    [props enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        value = [self normalize:value forKey:key];
        if (value != nil) [props setObject:value forKey:key];
    }];
}

-  (id)normalize:(id)value
          forKey:(NSString *)key {
    if (value == nil) return nil;
    if (([value isKindOfClass:[NSString class]]) && ([value isEqualToString:@"********"])) return nil;

    NSNumber *nType = [self.enums objectForKey:key];
    int iType = (nType != nil) ? [nType intValue] : kDefault;

    AppDelegate *appDelegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    RootController *rootController = appDelegate.rootController;
    BOOL customaryP = rootController.customaryP;
    long vlong;
    NSArray *varray;
    NSDate *vdate;
    NSNumber *vnumber;
    NSMutableDictionary *vdict;
    NSString *vstring;
    ZFCardinalDirection *vcardinal;
    switch (iType) {
        case kActor:
            if ([value isKindOfClass:[NSArray class]]) {
                varray = value;
                NSMutableArray *array = [NSMutableArray arrayWithCapacity:varray.count];
                [value enumerateObjectsUsingBlock:^(id actor, NSUInteger idx, BOOL *stop) {
                    [array addObject:[self normalize:actor forKey:key]];
                }];
                vstring = [self valuesPP:array withIndentLevel:2];
                return [vstring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            } else if ([value isKindOfClass:[NSString class]]) {
                NSDictionary *entity = [rootController.entities objectForKey:value];
                vstring = (entity != nil) ? [entity objectForKey:@"name"] : nil;
                if (vstring != nil) return vstring;
            }
           break;

        case kCelcius:
                 if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
            else if (![value isKindOfClass:[NSNumber class]]) break;
            else vlong = [value longValue];
            if (customaryP) vlong = ((vlong * 9) / 5) + 32;
            return [NSString stringWithFormat:@"%ld%@", vlong, customaryP ? @"\u2109" : @"\u2103"];

        case kColor:
            if (![value isKindOfClass:[NSDictionary class]]) break;
            vstring = [value objectForKey:@"model"];
            vdict = (vstring != nil) ? [value objectForKey:vstring] : nil;
            if (vdict == nil) break;
            return [NSString stringWithFormat:@"%@\n%*.*s %@", vstring, kKeyLength, kKeyLength, "",
                             [self paramsPP:vdict]];

        case kConditions:
            if (![value isKindOfClass:[NSDictionary class]]) break;
            vdict = [value mutableCopy];
            [vdict removeObjectForKey:@"code"];
            [self normalize:vdict];
            return [NSString stringWithFormat:@"\n%@", [self valuesPP:vdict withIndentLevel:2]];

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
            return [[vcardinal headingInEnglish] lowercaseString];

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
                  NSMutableArray *array = [NSMutableArray arrayWithCapacity:3];
                  [array addObject:latitude];
                  [array addObject:longitude];
                  if (varray.count >= 3) {
                      [array addObject:[self normalize:varray[2]
                                                forKey:@"altitude"]];
                  }
                  vstring = [self valuesPP:array withIndentLevel:2];
                  return [vstring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
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
            return [NSString stringWithFormat:@"%ld%@", vlong, customaryP ? @" feet" : @"m"];

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

        case kPhysical:
            if (![value isKindOfClass:[NSString class]]) break;
            vstring = [self valuesPP:[value componentsSeparatedByString:@", "] withIndentLevel:2];
            return [vstring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

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
             varray = value;
                   if ([value isKindOfClass:[NSString class]]) vlong = [value doubleValue];
              else if (([value isKindOfClass:[NSArray class]])
                           && (varray.count >= 3)
                           && ([key isEqualToString:@"batteryLevel"])) {
                  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
                  [dict setObject:[self normalize:varray[1]
                                           forKey:key]
                           forKey:@"goalCharge"];
                  [dict setObject:[self normalize:varray[2]
                                           forKey:key]
                           forKey:@"maxCharge"];
                  if (varray.count >= 4) {
                      vnumber = varray[3];
                           if ([vnumber isKindOfClass:[NSString class]]) vlong = [vnumber doubleValue];
                      else if (![value isKindOfClass:[NSNumber class]]) vlong = 0;
                      else vlong = [value longValue];
                      if (vlong != 0) {
                          [dict setObject:[self normalize:[NSDate dateWithTimeIntervalSinceNow:vlong]
                                                   forKey:@"nextSample"]
                                   forKey:@"chargeComplete"];
                      }
                  }
                  return [NSString stringWithFormat:@"%@\n%@",
                                   [self normalize:varray[0] forKey:key],
                                   [self valuesPP:dict withIndentLevel:2]];
            } else if (![value isKindOfClass:[NSNumber class]]) break;
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
            if (![value isKindOfClass:[NSDictionary class]]) break;
            vdict = [value mutableCopy];
            [vdict removeObjectForKey:@"albumArtURI"];
            vstring = [self milliseconds:[vdict objectForKey:@"duration"]];
            if (vstring != nil) [vdict setObject:vstring forKey:@"duration"];
            vstring = [self milliseconds:[vdict objectForKey:@"position"]];
            if (vstring != nil) [vdict setObject:vstring forKey:@"position"];
            return [NSString stringWithFormat:@"\n%@", [self valuesPP:vdict withIndentLevel:2]];

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

- (NSString *)paramsPP:(NSDictionary *)dict {
    NSUInteger capacity, *cptr;
    cptr = &capacity;

    capacity = 1;
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        NSString *param = [NSString stringWithFormat:@"%@:%@", key, value];
        *cptr += param.length + 1;
    }];

    NSMutableString *result = [NSMutableString stringWithCapacity:capacity];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        [result appendFormat:@"%@%@:%@", (result.length > 0) ? @"," : @"<", key, value];
    }];
    [result appendString:@">"];

    return result;
}

- (NSString *)valuesPP:(id)value {
  return [self valuesPP:value withIndentLevel:0];
}

- (NSString *)valuesPP:(id)value
       withIndentLevel:(int)indentLevel {
    NSMutableString *result = [[NSMutableString alloc] init];

    if ([value isKindOfClass:[NSDictionary class]]) {
        [value enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            NSString *string = [self valuePP:value];
            if (string == nil) return;
            if ((string.length > 36) && ([key isEqualToString:@"body"])) return;

            char keystring[kKeyLength + 1];
            NSString *alias = [self.alias objectForKey:key];
            if (alias != nil) key = alias;
            snprintf(keystring, sizeof keystring, "%s:", (const char *)[key UTF8String]);
            if (result.length > 0) [result appendString:@"\n"];
            [result appendFormat:@"%*.*s%-*.*s %@", indentLevel, indentLevel, "",
                    kKeyLength - indentLevel, kKeyLength-indentLevel, keystring, value];
        }];

        return result;
    }

    if ([value isKindOfClass:[NSArray class]]) {
        [value enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
            NSString *string = [self valuePP:value];
            if (string == nil) return;

            if (result.length > 0) [result appendString:@"\n"];
            [result appendFormat:@"%-*.*s %@", kKeyLength, kKeyLength, "", value];
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
