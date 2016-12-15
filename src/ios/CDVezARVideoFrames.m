/*
 * CDVezARVideoFrames.m
 *
 * Copyright 2016, ezAR Technologies
 * http://ezartech.com
 *
 * By @wayne_parrott
 *
 * Licensed under a modified MIT license. 
 * Please see LICENSE or http://ezartech.com/ezarstartupkit-license for more information
 *
 */

//#import <WebKit/WebKit.h>

#import "CDVezARVideoFrames.h"
#import "MainViewController.h"

//copied from cordova camera plugin
static NSString* toBase64(NSData* data) {
    SEL s1 = NSSelectorFromString(@"cdv_base64EncodedString");
    SEL s2 = NSSelectorFromString(@"base64EncodedString");
    SEL s3 = NSSelectorFromString(@"base64EncodedStringWithOptions:");
    
    if ([data respondsToSelector:s1]) {
        NSString* (*func)(id, SEL) = (void *)[data methodForSelector:s1];
        return func(data, s1);
    } else if ([data respondsToSelector:s2]) {
        NSString* (*func)(id, SEL) = (void *)[data methodForSelector:s2];
        return func(data, s2);
    } else if ([data respondsToSelector:s3]) {
        NSString* (*func)(id, SEL, NSUInteger) = (void *)[data methodForSelector:s3];
        return func(data, s3, 0);
    } else {
        return nil;
    }
}

@implementation CDVezARVideoFrames
{   
    BOOL watchVideoFrames;

    AVCaptureVideoDataOutput *videoDataOutput;
    NSString* watchVideoFramesCallbackId;
    dispatch_queue_t videoDataOutputQueue;
    CGRect webViewCropRect;
    CGRect videoCropRect;
    bool videoCropRectInited;
    
    long frameCnt;
    float targetFreqMS;
    CFTimeInterval lastFrameTimestamp;
}


// INIT PLUGIN - does nothing atm
- (void) pluginInitialize
{
    [super pluginInitialize];
    
    targetFreqMS = 1.0/16.0;
    lastFrameTimestamp = CACurrentMediaTime();
}


-(CDVPlugin*)getVideoOverlayPlugin
{
    MainViewController *ctrl = (MainViewController *)self.viewController;
    CDVPlugin* videoOverlayPlugin = [ctrl.pluginObjects objectForKey:@"CDVezARVideoOverlay"];
    return videoOverlayPlugin;
}

-(BOOL) hasVideoOverlayPlugin
{
    return !![self getVideoOverlayPlugin];
}

- (AVCaptureSession *) getAVCaptureSession
{
    AVCaptureSession* result;

    // Find AVCaptureSession
    NSString* methodName = @"getAVCaptureSession";
    SEL selector = NSSelectorFromString(methodName);
    result = (AVCaptureSession*)[[self getVideoOverlayPlugin] performSelector:selector];

    return result;
}

-(BOOL) isCameraRunning {
    // Find AVCaptureSession
    NSString* methodName = @"isCameraRunning";
    SEL selector = NSSelectorFromString(methodName);
    BOOL result = (BOOL)[[self getVideoOverlayPlugin] performSelector:selector];
    
    return result;
}

-(BOOL) isFrontCameraRunning {
    return ![self isBackCameraRunning];
}

-(BOOL) isBackCameraRunning {
    // Find AVCaptureSession
    NSString* methodName = @"isFrontCameraRunning";
    SEL selector = NSSelectorFromString(methodName);
    BOOL result = (BOOL)[[self getVideoOverlayPlugin] performSelector:selector];
    
    return result;
}


- (void) watchVideoFrames:(CDVInvokedUrlCommand*)command
{
    if (![self isCameraRunning]) {
        //error camera must be running
        CDVPluginResult* result = nil;
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera is not running"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    };
    
    CGFloat x = [[command argumentAtIndex:0] unsignedIntegerValue];
    CGFloat y  = [[command argumentAtIndex:1] unsignedIntegerValue];
    CGFloat width = [[command argumentAtIndex:2] unsignedIntegerValue];
    CGFloat height  = [[command argumentAtIndex:3] unsignedIntegerValue];
    webViewCropRect = CGRectMake(x,y,width,height);

    if (!videoDataOutput) {
        videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        OSType format = kCVPixelFormatType_32BGRA;
        NSDictionary *rgbOutputSettings  = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:format]
                                                                       forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        
        [videoDataOutput setVideoSettings:rgbOutputSettings];
        [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
        videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [videoDataOutput setSampleBufferDelegate:self queue: videoDataOutputQueue];
        if ( [[self getAVCaptureSession] canAddOutput:videoDataOutput] ){
            [[self getAVCaptureSession] addOutput:videoDataOutput];
        }
    }
    
    if (!videoDataOutput) {
        //TODO return error
        return;
    }
    
    watchVideoFramesCallbackId = command.callbackId;
    watchVideoFrames = YES;
    
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
}

- (void) clearVideoFramesWatch:(CDVInvokedUrlCommand*)command
{
    if (videoDataOutput) {
        [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
        [[self getAVCaptureSession] removeOutput:videoDataOutput];
        videoDataOutput = nil;
    }
    
    //TODO make thread safe update to only set these values when method
    //  captureOutput:didOutputSampleBuffer:fromConnection: is not executing
    watchVideoFrames = NO;
    videoCropRectInited = NO;
    watchVideoFramesCallbackId = NULL;
    
    //return success and then start receiving video frames
    CDVPluginResult* result = nil;
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

#pragma mark - Protocol AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!watchVideoFrames) {
        return;
    }
    
    if (!videoCropRectInited) {
        //scale/translate webViewCropRect to video size
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        size_t videoWidth = CVPixelBufferGetWidth(imageBuffer);
        size_t videoHeight = CVPixelBufferGetHeight(imageBuffer);
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);

        CGRect webViewFrame = [self webView].frame; //should be portrait

        //video is in landscape; webview is portrait
        //compute video/webview scale, must rotate webview rect to landscape
        CGFloat landscapeXScale = videoWidth / webViewFrame.size.height;
        CGFloat landscapeYScale = videoHeight / webViewFrame.size.width;

        videoCropRect = CGRectMake(
            webViewCropRect.origin.x * landscapeXScale,
            webViewCropRect.origin.y * landscapeYScale,
            webViewCropRect.size.width * landscapeXScale,
            webViewCropRect.size.height * landscapeYScale);

        videoCropRectInited = YES;
    }

    //CFTimeInterval elapseTime = CACurrentMediaTime() - lastFrameTimestamp;
    //if (elapseTime < targetFreqMS) return;
    
    lastFrameTimestamp = CACurrentMediaTime();
    frameCnt++;
    //if (frameCnt % 1900 > 1800) return; //skip 100 frames to give webview time to GC
    
    NSData *imageData;
    CDVPluginResult* pluginResult;
    
    imageData = [self nsData64CropFromSampleBuffer:sampleBuffer];
    NSString *data64URLString = [NSString stringWithFormat:@"data:image/jpg;base64,%@", toBase64(imageData)];
        
    pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                        //messageAsArrayBuffer:imageData];
                          messageAsString: data64URLString];
    
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:watchVideoFramesCallbackId];
    
}


// Create a nsdata for image bytes
- (NSData *) nsData64CropFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
//- (NSString *) nsData64CropFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t bytesPerPixel = 4; //bytesPerRow / width;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context =
        CGBitmapContextCreate(baseAddress, width, height, 8,
                            bytesPerRow, colorSpace,
                            kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

    CGImageRef cgImage = CGBitmapContextCreateImage(context);

    // Free up the context and color space; unlock the pixel buffer
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    
    // Create rectangle from middle of current image
    CGRect croprect = videoCropRect;
    //croprect = CGRectMake(videoCropRect.origin.x, videoCropRect.origin.y,
    //                             videoCropRect.size.width, videoCropRect.size.height);
    
    CGImageRef imageRef = CGImageCreateWithImageInRect(cgImage, croprect);
    
    //back camera in port: UIImageOrientationRight
    //front camera in port: UIImageOrientationLeftMirrored
    UIImageOrientation orientation = [self isFrontCameraRunning] ? UIImageOrientationLeftMirrored : UIImageOrientationRight;
    orientation = UIImageOrientationLeftMirrored;
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef scale:(CGFloat)1.0 orientation:orientation];
    CGImageRelease(imageRef);
    
    NSData *jpgImageData = UIImageJPEGRepresentation(croppedImage,0.5);
    CGImageRelease(cgImage);
    
    return jpgImageData;
}



@end
