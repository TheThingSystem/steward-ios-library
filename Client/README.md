##Client Library

This library is synactic sugar over the top of the [Socket Rocket](https://github.com/square/SocketRocket) web socket library and is intended to simplify common tasks when building [clients](http://thethingsystem.com/dev/Clients.html) for the [steward](https://github.com/TheThingSystem/steward) under iOS.

_**Note:** This library should be considered a draft release. It's likely that the API will evolve considerably over time. Right now for instance JSON is passed back to your code by the library. Future releases may pre-parse the JSON messages and pass them as `NSDictionary` objects instead. Pull requests for enhancements, refactoring and bug fixes are welcome._

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
        NSString *parameters = @"{ \\\"brightness\\\": 100, \\\"color\\\": { \\\"model\\\": \\\"rgb\\\", \\\"rgb\\\": { \\\"r\\\": 255, \\\"g\\\": 255, \\\"b\\\": 255 }}}";
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

If you wish to make an authenticated request, then you should instead,

    client.authenticate = YES;
    client.clientID = clientIdentity;
    client.secret = ClientAuthenticationSecret;
    [client performWithDevice:device andRequest:request andParameters:nil];	

where the client ID and the authentication secret can be obtained from the steward's own [Client Bootstrapping web service](http://thethingsystem.com/dev/Instructions-for-starting-the-Steward.html). 

_**Note:** To make an un-authenticated call to the steward you will need to go to your steward settings and turn "Security Services" to the "No" setting. This step turns secure connections on your local LAN off for clients and authentication for read/write is no longer required on the LAN._

[![Analytics](https://ga-beacon.appspot.com/UA-44378714-2/TheThingSystem/steward-ios-library/client/README)](https://github.com/igrigorik/ga-beacon)