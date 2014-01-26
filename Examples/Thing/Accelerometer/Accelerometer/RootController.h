//
//  RootController.h
//  Accelerometer
//
//  Created by Alasdair Allan on 08/01/2014.
//  Copyright (c) 2014 The Thing System. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CMMotionManager;

@interface RootController : UIViewController

@property (strong, nonatomic) CMMotionManager *motionManager;

@end
