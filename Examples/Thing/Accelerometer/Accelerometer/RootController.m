//
//  RootController.m
//  Accelerometer
//
//  Created by Alasdair Allan on 08/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>

#import "RootController.h"
#import "Thing.h"

@interface RootController ()

@end

@implementation RootController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    Thing *thing = [Thing sharedThing];
    NSLog(@"Thing Library v%@", [Thing version]);
    
    // create a device
    Device *device = [[Device alloc] initWithDevice:@"/device/sensor/phone/iphone"];
    device.name = @"iPhone";
    device.maker = @"Apple";
    device.serial = [Util uniqueID];
    device.udn = [NSString stringWithFormat:@"%@-iphone", device.serial];
    
    device.properties = @{ @"roll":@"radians",
                           @"pitch":@"radians",
                           @"yaw":@"radians",
                           @"x acceleration":@"g",
                           @"y acceleration":@"g",
                           @"z acceleration":@"g",
                           @"x gravity":@"g",
                           @"y gravity":@"g",
                           @"z gravity":@"g",
                           @"x rotation":@"radians/s",
                           @"y rotation":@"radians/s",
                           @"z rotation":@"radians/s"
                         };

    // Add the device to our thing
    thing.device = device;

    
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.deviceMotionUpdateInterval =  1.0 / 10.0;
    [self.motionManager startDeviceMotionUpdates];
    if (self.motionManager.deviceMotionAvailable ) {
        NSTimer * timer = [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(sendData:) userInfo:nil repeats:YES];
    } else {
        [self.motionManager stopDeviceMotionUpdates];
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)sendData:(NSTimer *)timer  {
    CMDeviceMotion *motionData = self.motionManager.deviceMotion;
    
    CMAttitude *attitude = motionData.attitude;
    CMAcceleration gravity = motionData.gravity;
    CMAcceleration userAcceleration = motionData.userAcceleration;
    CMRotationRate rotate = motionData.rotationRate;

    [[Thing sharedThing] dispatchWithInformation:@{ @"roll":[NSNumber numberWithDouble:attitude.roll],
                                                    @"pitch":[NSNumber numberWithDouble:attitude.pitch],
                                                    @"yaw":[NSNumber numberWithDouble:attitude.yaw],
                                                    @"x acceleration":[NSNumber numberWithDouble:userAcceleration.x],
                                                    @"y acceleration":[NSNumber numberWithDouble:userAcceleration.y],
                                                    @"z acceleration":[NSNumber numberWithDouble:userAcceleration.z],
                                                    @"x gravity":[NSNumber numberWithDouble:gravity.x],
                                                    @"y gravity":[NSNumber numberWithDouble:gravity.y],
                                                    @"z gravity":[NSNumber numberWithDouble:gravity.z],
                                                    @"x rotation":[NSNumber numberWithDouble:rotate.x],
                                                    @"y rotation":[NSNumber numberWithDouble:rotate.y],
                                                    @"z rotation":[NSNumber numberWithDouble:rotate.z]
                                                   } ];
}

@end
