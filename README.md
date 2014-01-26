The Thing System iOS Library
===================

This library is a draft release of [The Thing System](http://thethingsystem.com) iOS Library. It serves as a convenience layer ad is intended to simplify common tasks when [developing](http://thethingsystem.com/dev/Developer.html) both [things](http://thethingsystem.com/dev/Things.html) and [clients](http://thethingsystem.com/dev/Clients.html) on iOS devices which talk to The Thing System [steward software](https://github.com/TheThingSystem/steward).

The iOS library has been divided into two seperate static libraries, a `libClient.a` and a`libThing.a`. This is intended to minimise the addition of redundant code to your application. However there is no reason why both libraries cannot be used inside a single application.

Pull requests for enhancements, refactoring and bug fixes are welcome.

_*Note:* This library should be considered a draft release. It's likely that the API will evolve considerably over time. Right now for instance JSON is passed back to your code by the library in many places. Future releases may pre-parse the JSON messages and pass them as `NSDictionary` objects instead._

##Installation

You can either copy all the files for the relevant library into your porject, or include the appropriate static library as a subproject with either `libThing.a` or `libClient.a` as targets. 

However the easiest method is to use the bianry release and drop the [pre-built binaries](https://github.com/TheThingSystem/steward-ios-library/releases/tag/0.1) along with the asociated header files for the static libraries into your project. 

*Note:* If you do this, you must add `-ObjC` to the "Other Linker Flags" option in your project settings.

###Dependencies

Your application must be linked against the following additional frameworks to use the Thing library,

* SystemConfiguration.framework

and the following additional frameworks and dynamic libraries for the Client library,

* SystemConfiguration.framework
* Security.framework
* CFNetwork.framework
* libicucore.dylib

##Building Things

This library is synactic sugar over the top of the [Cocoa Async Socket](https://github.com/robbiehanson/CocoaAsyncSocket) library and is intended to simplify common tasks when building things for the steward under iOS.

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

##Building Clients

This library is synactic sugar over the top of the [Socket Rocket](https://github.com/square/SocketRocket) web socket library and is intended to simplify common tasks when building clients for the steward under iOS.

###Monitoring the event stream

If you want to monitor the event stream from the steward you should

    #import "Client.h"

and then grab a shared instance of the `Client` class, declare yourself a delgate

	Client *client = [Client sharedClient];
	client.delegate = self;

and then declare your class as a `<ClientDelegate>`. Then go ahead and find the steward,

	[client findSteward];	

which will start the process of looking for an active steward via [mDNS](http://en.wikipedia.org/wiki/Multicast_DNS) (also known as Bonjour). When the steward is found you will recieve a delegate callback of the form `stewardFoundWithAddress:` at which point you can start monitoring for events,

	- (void)stewardFoundWithAddress:(NSString *)ipAddress {
		Client *client = [Client sharedClient];
        [client startMonitoringEvents];
	}

Incoming messages from the steward will trigger the `recievedEventMessage` callback,

    - (void)recievedEventMessage:(NSString *)message {
        NSLog(@"json = %@", message);
    }

Messages will be in JSON format. This is a firehose of all messages broadcast by the steward, e.g.

    { ".updates":[{
          "updated":1390766348015,
          "level":"alert",
          "message":"please push pairing button on Hue bridge",
          "whoami":"device/2",
          "name":"Phillips hue (192.168.1.100)",
          "info":{
            "whatami":"/device/gateway/hue/bridge",
            "whoami":"device/2",
            "name":"Phillips hue (192.168.1.100)",
            "status":"reset",
            "info":{}
       }}]
    }

would be an alert message to indicate that while the steward can see a Philips Hue hub on the network, it is not yet authorised to connect to it to manage the lights.

If the steward is not found you will recieve a `stewardNotFoundWithError:` callback,

    - (void)stewardNotFoundWithError:(NSError *)error {
    
    }

Once you start monitoring for events you can stop monitoring at any time by calling,

	[client stopMonitoringEvents];

###Getting a list of devices

If you want to control a single device rather than a class of devices then you'll need the `deviceID` of the device you want to control. You can obtain a list of devices known to the steward. To do so you should 

    #import "Client.h"

and then grab a shared instance of the `Client` class, declare yourself a delgate

	Client *client = [Client sharedClient];
	client.delegate = self;

and declare your class as a `<ClientDelegate>`, and then find the steward,

	[client findSteward];	

which will start the process of looking for an active steward via [mDNS](http://en.wikipedia.org/wiki/Multicast_DNS) (also known as Bonjour). When the steward is found you will recieve a callback of the form `stewardFoundWithAddress:` at which point you can ask the steward for a list of associated devices,

    - (void)stewardFoundWithAddress:(NSString *)ipAddress {
		Client *client = [Client sharedClient];
        [client availableDevices];
    }

The response from the steward will trigger the `recievedDeviceList` callback,

	    - (void)recievedDeviceList:(NSString *)message {
	        NSLog(@"json = %@", message);
	    }

the message will be in JSON format.

###Calling 'Perform' on a device or devices

If you want to control a device—ask it to perform an action—you can do so by, 

    #import "Client.h"

and then grab a shared instance of the `Client` class, declare yourself a delgate

	Client *client = [Client sharedClient];
	client.delegate = self;

and declare your class as a `<ClientDelegate>`, and then find the steward,

	[client findSteward];	

which will start the process of looking for an active steward via [mDNS](http://en.wikipedia.org/wiki/Multicast_DNS) (also known as Bonjour). When the steward is found you will recieve a callback of the form `stewardFoundWithAddress:` at which point you can make a request to the steward.

Here for instance we ask the steward to talk to `device/lighting`, short hand for "all lightbulbs", and turn them "on" with a brightness of 100% and a colour of white, i.e. RGB values of 255.

    - (void)stewardFoundWithAddress:(NSString *)ipAddress {
		Client *client = [Client sharedClient];
        NSString *device = @"device/lighting";
        NSString *request = @"on";
        NSString *parameters = @"{ \"brightness\": 100, \"color\": { \"model\": \"rgb\", \"rgb\": { \"r\": 255, \"g\": 255, \"b\": 255 }}}";
        [client performWithDevice:device andRequest:request andParameters:parameters];
    }	

if at a future point we want to turn all the lightbulbs back off then we would call,

    NSString *device = @"device/lighting";
    NSString *request = @"off";
    [client performWithDevice:device andRequest:request andParameters:nil];	

The response message from the steward, including any error messages, will be dispatched to the `recievedPerformResponse:` callback

    -(void)recievedPerformResponse:(NSString *)message {
        NSLog(@"json = %@", message);
    }

in JSON format.

##Example Code

The library ships with [example code](https://github.com/TheThingSystem/steward-ios-library/tree/master/Examples) illustrating use of both the Thing and Client portions of the library.

##License

This library is released under the [MIT license](http://en.wikipedia.org/wiki/MIT_License).

_Copyright (c) 2014 The Thing System, Inc._

_Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:_

_The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software._

_THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE._

###Socket Rocket

This library makes use of the [Socket Rocket](https://github.com/square/SocketRocket) library from Square which is released under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

_Copyright (c) 2012 Square Inc._

_Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)._

_Unless required by applicable law or agreed to in writing, software  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License._

###Cocoa Async Socket

This library makes use of the [Cocoa Async Socket](https://github.com/robbiehanson/CocoaAsyncSocket) library, an asynchronous socket networking library for OS X and iOS.

_These classes have been placed into the public domain by their author, Robbie Hanson of [Deusty LLC](http://deusty.blogspot.co.uk). They are updated and maintained by Deusty LLC and the Apple development community._

[![Analytics](https://ga-beacon.appspot.com/UA-44378714-2/TheThingSystem/steward/README)](https://github.com/igrigorik/ga-beacon)
