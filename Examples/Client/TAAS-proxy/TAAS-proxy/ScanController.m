//
//  ScanController.m
//  Client
//
//  Created by Alasdair Allan on 27/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "ScanController.h"

@interface ScanController ()

@end

@implementation ScanController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.capture = [[ZXCapture alloc] init];
    self.capture.rotation = 90.0f;

    // Use the back camera
    self.capture.camera = self.capture.back;

    self.capture.layer.frame = self.view.bounds;
    [self.view.layer addSublayer:self.capture.layer];

    [self.view bringSubviewToFront:self.navigationBar];
    [self.view bringSubviewToFront:self.label];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.capture.delegate = self;
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.capture.delegate = nil;

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (IBAction)cancel:(id)sender {
    if ( [self.delegate respondsToSelector:@selector(closedWithoutSecret)] ) {
        [self.delegate closedWithoutSecret];
    }
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - ZXCaptureDelegate Methods

- (void)captureResult:(ZXCapture*)capture result:(ZXResult*)result {
    if (result) {
        // dispatch URL
        if ( [self.delegate respondsToSelector:@selector(closedWithURL:)] ) {
            [self.delegate closedWithURL:[NSURL URLWithString:result.text]];
        }

        // dispatch secret only
        NSArray *array = [result.text componentsSeparatedByString:@"="];
        NSString *secret = array[1];
        NSRange range = [secret rangeOfString:@"&"];
        if (range.location != NSNotFound) secret = [secret substringToIndex:range.location];
        if ( [self.delegate respondsToSelector:@selector(closedWithSecret:)] ) {
            [self.delegate closedWithSecret:secret];
        }

        // Vibrate
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
}

- (void)captureSize:(ZXCapture*)capture width:(NSNumber*)width height:(NSNumber*)height {

}

@end
