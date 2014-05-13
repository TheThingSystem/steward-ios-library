The TAAS-proxy Example
======================

This example shows how to operate a background proxy to your steward,
which may be useful if running a program that talks to the steward,
but your steward isn't available locally.

This example is still a work in progress.
The TODO list is:

- figure out how to save and restore TOTP information in the Client library

- update the Client library to know about the [TAAS cloud](http://github.com/TheThingSystem/taas-server)

- fill-in the error response bodies in TAASConnection.m

- update the app to run in the background

    - keep track of foreground/background status

    - do not upgrade the main screen in the background

- repurpose the main screen to show status and console notices from the steward

- test, test, and test!

Please note that this program is **NOT** intended to be submitted to the AppStore.
It is for testing and demonstration purposes only!


Acknowledgements
----------------
Many thanks to the folks at [CocoaPods](http://cocoapods.org) for their fine package management system.

A special thanks to Robbie Hanson for his excellent [CocoaHTTPServer](https://github.com/robbiehanson/CocoaHTTPServer) library.
