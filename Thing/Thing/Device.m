//
//  Device.m
//  Thing
//
//  Created by Alasdair Allan on 17/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import "Thing.h"

@implementation Device

- (id)init {
	if( (self = [super init]) ) {
        
    }
    return self;
}

- (id)initWithDevice:(NSString *)name {
    if ((self = [super init])) {
        self.device = name;
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)decoder {
	if ((self = [super init])) {
        self.device = [decoder decodeObjectForKey:@"device"];
        self.name = [decoder decodeObjectForKey:@"name"];
        self.maker = [decoder decodeObjectForKey:@"maker"];
        self.serial = [decoder decodeObjectForKey:@"serial"];
        self.udn = [decoder decodeObjectForKey:@"udn"];
        self.properties = [decoder decodeObjectForKey:@"properties"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.device forKey:@"device"];
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.maker forKey:@"maker"];
    [encoder encodeObject:self.serial forKey:@"serial"];
    [encoder encodeObject:self.udn forKey:@"udn"];
    [encoder encodeObject:self.properties forKey:@"properties"];
}

@end
