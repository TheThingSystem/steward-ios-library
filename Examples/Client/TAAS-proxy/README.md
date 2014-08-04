The TAAS-proxy Example
======================

Also, the app requires iOS 7.0 or later.

This app, which requires iOS 7.1 or later, does three things:

- It lets you tell the steward to perform tasks or report status

- It operates as a background proxy to the steward

- It provides a mechanism for you to have [Siri](http://en.wikipedia.org/wiki/Siri) tell the steward to perform tasks or report status

The first function is used when the app is running in the foreground;
the other two functions require that the app be running in the background as a proxy to the steward.
The latter two functions are not consistent with the Apple's current view on app behavior.
As such, this app will be rejected if submitted to the AppStore,
and is intended for testing and demonstration purposes only!


Configuration
-------------

**TODO: discuss QRcode, cert files (Certs/), and json files (Scripts/)**

Advanced Configuration
----------------------

**TODO: discuss proxy.pac (Web/) and self-signed cert (Certs/)**


A Persient Proxy to the Steward
-------------------------------

When the app is started,
it listens for steward advertisements via bonjour.
The app uses the camera on the device to scan a QRcode via

        https://steward.local:8888/client

which includes information on how to talk to the steward via the TAAS cloud.

Once the app is talking to the steward,
it does several things:

* console information is presented in the UI

* it listens on port 8884 for http connections, which it then transparently routes to the steward:

    * via WebSockets

    * via HTTP

    * via voice commands to report status

* if you have copied files to the app's _Web/_ directory, then those will be served directly

* if you have copied CER files to the app's _Certs/_ directory,
then those will be used for [SSL pinning](http://en.wikipedia.org/wiki/Transport_Layer_Security#Certificate_pinning)
(A CER file is a certificate file that is encoded using the
[the DER binary format](http://en.wikipedia.org/wiki/Distinguished_Encoding_Rules#DER_encoding))

        openssl x509 -outform der -in server.crt -out server.cer

* as the device's network configuration changes,
the connection to the steward is pre-emptively re-established

The upshot of all this is that both web and voice-enabled applications can talk to

        http://127.0.0.1:8884/

and get to the steward,
regardless of where you are,
or the steward is,
as long as there is network connectivity between the device and the steward.


Keep Reading, If You Must!
--------------------------
This iOS application does something that Apple doesn't want to happen on iOS:
it implements a long-lived network listener.
In order to do this, we use two tricks:

* the app is declared as a media/voip app,
which allows us to mark a connection to the steward as persistent

* the app is declared as a location-aware app,
which allows us to receive significant location change (SLC) notifications in the background

It turns out that you have to do both of these things in order to make things work.
In particular, the app may not be able to reach the steward either locally or via the TAAS cloud;
so it's possible that there isn't a connection to mark as persistent.

When the app enters the background,
it begins a background task that's designed to keep the app running until iOS runs the clock down and suspends the app.
However,
when an app is suspended,
it still receives SLC notifications,
which cause the app to be resumed in the background.

That's the current operational behavior.
Of course,
when iOS 8 comes out,
it is possible that either:

* there will improved methods for implementing this functionality; or,

* it will no longer be possible to implement this functionality.

Time will tell -- but for now, enjoy!


Acknowledgements
----------------
Many thanks to the folks at [CocoaPods](http://cocoapods.org) for their fine package management system.

A special thanks to [Robbie Hanson](https://github.com/robbiehanson) for his excellent [CocoaHTTPServer](https://github.com/robbiehanson/CocoaHTTPServer) library.

A super thanks to [Nick Lockwood](https://github.com/nicklockwood) for his many excellent packages.

And many thanks to the contributors of all the other CocoaPods packages used by this example:

* [MDCDamerauLevenshtein](https://github.com/modocache/MDCDamerauLevenshtein) by [@modocache](https://github.com/modocache)
* [MHPrettyDate](https://github.com/bobjustbob/MHPrettyDate) by [@bobjustbob](https://github.com/bobjustbob)
* [RNPinnedCertValidator](https://github.com/rnapier/RNPinnedCertValidator) by [@rnapier](https://github.com/rnapier)
* [TSMessages/](https://github.com/toursprung/TSMessages/) by [@toursprung](https://github.com/toursprung)
* [ZFCardinalDirection](https://github.com/flightblog/ZFCardinalDirection) by [@flightblog](https://github.com/flightblog)
* [ZXingObjC](https://github.com/TheLevelUp/ZXingObjC) by [@TheLevelUp](https://github.com/TheLevelUp)
