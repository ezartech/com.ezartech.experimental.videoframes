/**
 * CDVezARVideoOverlay.h
 *
 * Copyright 2016, ezAR Technologies
 * http://ezartech.com
 *
 * By @wayne_parrott
 *
 * Licensed under a modified MIT license. 
 * Please see LICENSE or http://ezartech.com/ezarstartupkit-license for more information
 */

#import <AVFoundation/AVFoundation.h>

#import "Cordova/CDV.h"

/**
 *  
 */
@interface CDVezARVideoFrames : CDVPlugin <AVCaptureVideoDataOutputSampleBufferDelegate>

- (void) watchVideoFrames:(CDVInvokedUrlCommand*)command;

- (void) clearVideoFramesWatch:(CDVInvokedUrlCommand*)command;

@end



