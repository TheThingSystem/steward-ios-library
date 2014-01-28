##Thing Library

This library is synactic sugar over the top of the [Cocoa Async Socket](https://github.com/robbiehanson/CocoaAsyncSocket) library and is intended to simplify common tasks when building [things](http://thethingsystem.com/dev/Things.html) for the [steward](https://github.com/TheThingSystem/steward) under iOS.

_Note: This library should be considered a draft release. It's likely that the API will evolve considerably over time. Right now for instance JSON is passed back to your code by the library. Future releases may pre-parse the JSON messages and pass them as `NSDictionary` objects instead. Pull requests for enhancements, refactoring and bug fixes are welcome._

###Building a TSRP things

If a thing needs to report sensor readings, or an event happening, to the [steward](https://github.com/TheThingSystem/steward) it can implement the [Thing Sensor Reporting Protocol](http://thethingsystem.com/dev/Thing-Sensor-Reporting-Protocol.html) (TSRP). This is a simple multicast UDP based protocol. For things that need to both report back to the steward and received requests to perform actions, or make measurements at certain times, you should look at the [Simple Thing Protocol](http://thethingsystem.com/dev/Simple-Thing-Protocol.html) instead.

To build a [TSRP](http://thethingsystem.com/dev/Thing-Sensor-Reporting-Protocol.html) thing you should

    #import "Thing.h"

and then grab a shared instance of the `Client` class, declare yourself a delgate

	Thing *thing = [Thing sharedThing];
	thing.delegate = self;

and then declare your class as a `<ThingDelegate>`. 

You should then create a device instance, e.g.

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

and then add the device to the thing,

     thing.device = device;

you can then dispatch a sensor report to the steward using the `dispatchWithInformation:` method,

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

[![Analytics](https://ga-beacon.appspot.com/UA-44378714-2/TheThingSystem/steward-ios-library/thing/README)](https://github.com/igrigorik/ga-beacon)