//
//  ScanController.h
//  Client
//
//  Created by Alasdair Allan on 27/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZXingObjC.h"

@protocol ScanControllerDelegate <NSObject>

@optional
- (void)closedWithSecret:(NSString *)secret;
- (void)closedWithURL:(NSURL *)url;
- (void)closedWithoutSecret;

@end


@interface ScanController : UIViewController <ZXCaptureDelegate>

@property (nonatomic, weak) id <ScanControllerDelegate> delegate;

@property (nonatomic, strong) ZXCapture* capture;
@property (unsafe_unretained, nonatomic) IBOutlet UILabel *label;
@property (unsafe_unretained, nonatomic) IBOutlet UINavigationBar *navigationBar;

- (IBAction)cancel:(id)sender;

@end
