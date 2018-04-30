//
//  MIT License
//
//  Copyright (c) 2014 Bob McCune http://bobmccune.com/
//  Copyright (c) 2014 TapHarmonic, LLC http://tapharmonic.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "THCameraController.h"
#import <AVFoundation/AVFoundation.h>

const CGFloat THZoomRate = 1.0f;

// KVO Contexts
static const NSString *THRampingVideoZoomContext;
static const NSString *THRampingVideoZoomFactorContext;

@implementation THCameraController

- (BOOL)setupSessionInputs:(NSError **)error {

    // Listing 7.4
    BOOL success = [super setupSessionInputs:error];
    if (success) {
        
        [self.activeCamera addObserver:self forKeyPath:@"videoZoomFactor" options:0 context:&THRampingVideoZoomFactorContext];
        [self.activeCamera addObserver:self forKeyPath:@"rampingVideoZoom" options:0 context:&THRampingVideoZoomContext];
    }

    return success;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context {

    // Listing 7.4
    if (context == &THRampingVideoZoomContext) {
        [self updateZoomingDelegate];
    } else if (context == &THRampingVideoZoomFactorContext) {
        if (self.activeCamera.isRampingVideoZoom) {
            [self updateZoomingDelegate];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateZoomingDelegate {

    // Listing 7.4
    CGFloat currentZoom = self.activeCamera.videoZoomFactor;
    CGFloat maxZoom = [self maxZoomFactor];
    CGFloat value = log(currentZoom) / log(maxZoom);
    [self.zoomingDelegate rampedZoomToValue:value];
}

- (BOOL)cameraSupportsZoom {

    // Listing 7.2

    return self.activeCamera.activeFormat.videoMaxZoomFactor > 1.0;
}

- (CGFloat)maxZoomFactor {

    // Listing 7.2

    return MIN(self.activeCamera.activeFormat.videoMaxZoomFactor, 4);
}

- (void)setZoomValue:(CGFloat)zoomValue {

    // Listing 7.2
    AVCaptureDevice *device = self.activeCamera;
    if (!device.isRampingVideoZoom) {
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            CGFloat max = [self maxZoomFactor];
            device.videoZoomFactor = pow(max, zoomValue);
            [device unlockForConfiguration];
        } else {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }

}

- (void)rampZoomToValue:(CGFloat)zoomValue {

    // Listing 7.3
    CGFloat zoomFactor = pow([self maxZoomFactor], zoomValue);
    AVCaptureDevice *device = self.activeCamera;
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        [device rampToVideoZoomFactor:zoomFactor withRate:THZoomRate];
        [device unlockForConfiguration];
    } else {
        [self.delegate deviceConfigurationFailedWithError:error];
    }
}

- (void)cancelZoom {

    // Listing 7.3
    NSError *error = nil;
    if ([self.activeCamera lockForConfiguration:&error]) {
        [self.activeCamera cancelVideoZoomRamp];
        [self.activeCamera unlockForConfiguration];
    } else {
        [self.delegate deviceConfigurationFailedWithError:error];
    }

}

@end

