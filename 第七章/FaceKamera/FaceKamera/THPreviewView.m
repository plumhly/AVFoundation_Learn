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

#import "THPreviewView.h"

@interface THPreviewView ()

    // Listing 7.9
@property (nonatomic, strong) CALayer *overlayLayer;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) NSMutableDictionary *faceLayers;

@end

@implementation THPreviewView

+ (Class)layerClass {

    // Listing 7.9

    return [AVCaptureVideoPreviewLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupView];
    }
    return self;
}

- (void)setupView {

    // Listing 7.10
    self.faceLayers = [NSMutableDictionary dictionary];
    
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    self.overlayLayer = [CALayer layer];
    self.overlayLayer.frame = self.bounds;
    self.overlayLayer.sublayerTransform = CATransform3DMakePerspective(1000);
    [self.previewLayer addSublayer:_overlayLayer];

}

- (AVCaptureSession*)session {

    // Listing 7.9

    return self.previewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session {

    // Listing 7.10
    self.previewLayer.session = session;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {

    // Listing 7.9

    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (void)didDetectFaces:(NSArray *)faces {

    // Listing 7.11
    NSArray *faceArray = [self transformedFacesFromFaces:faces];

    // Listing 7.12
    NSMutableArray *loseFace = [self.faceLayers.allKeys mutableCopy];
    for (AVMetadataFaceObject *face in faceArray) {
        NSNumber *faceId = @(face.faceID);
        [loseFace removeObject:faceId];
        CALayer *layer = self.faceLayers[faceId];
        if (!layer) {
            layer = [self makeFaceLayer];
            self.faceLayers[faceId] = layer;
            [self.overlayLayer addSublayer:layer];
        }
        layer.transform = CATransform3DIdentity;
        layer.frame = face.bounds;
        
        if (face.hasRollAngle) {
            CATransform3D t = [self transformForRollAngle:face.rollAngle];
            layer.transform = CATransform3DConcat(layer.transform, t);
        }
        
        if (face.hasYawAngle) {
            CATransform3D t = [self transformForYawAngle:face.yawAngle];
            layer.transform = CATransform3DConcat(layer.transform, t);
        }
        
    }
    
    for (NSNumber *key in loseFace) {
        CALayer *layer = _faceLayers[key];
        [layer removeFromSuperlayer];
        [self.faceLayers removeObjectForKey:key];
    }

    // Listing 7.13

}

- (NSArray *)transformedFacesFromFaces:(NSArray *)faces {

    // Listing 7.11
    NSMutableArray *allFaces = [NSMutableArray array];
    for (AVMetadataObject *face in faces) {
      AVMetadataObject *transformData =   [self.previewLayer transformedMetadataObjectForMetadataObject:face];
        [allFaces addObject:transformData];
    }

    return allFaces;
}

- (CALayer *)makeFaceLayer {

    // Listing 7.12
    CALayer *layer = [CALayer layer];
    layer.borderWidth = 5;
    layer.borderColor = [UIColor colorWithRed:0.118 green:0.517 blue:0.877 alpha:1.0].CGColor;

    return layer;
}

// Rotate around Z-axis
- (CATransform3D)transformForRollAngle:(CGFloat)rollAngleInDegrees {

    // Listing 7.13
    CGFloat rollRadius = THDegreesToRadians(rollAngleInDegrees);
    CATransform3D t = CATransform3DMakeRotation(rollRadius, 0, 0, 1);

    return t;
}

// Rotate around Y-axis
- (CATransform3D)transformForYawAngle:(CGFloat)yawAngleInDegrees {

    // Listing 7.13
    CGFloat yawRadius = THDegreesToRadians(yawAngleInDegrees);
    CATransform3D t = CATransform3DMakeRotation(yawRadius, 0, -1, 0);

    return CATransform3DConcat(t, [self orientationTransform]);
}

- (CATransform3D)orientationTransform {

    // Listing 7.13
    CGFloat angle;
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
          
        case UIDeviceOrientationLandscapeLeft:
            angle = M_PI / 2;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            angle = -M_PI / 2;
            break;
        default:
            angle = 0;
            break;
    }

    return CATransform3DMakeRotation(angle, 0, 0, -1);
}

// The clang pragmas can be removed when you're finished with the project.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

static CGFloat THDegreesToRadians(CGFloat degrees) {

    // Listing 7.13
    CGFloat angle = degrees * M_PI / 180;

    return angle;
}

static CATransform3D CATransform3DMakePerspective(CGFloat eyePosition) {

    // Listing 7.10
    
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1 / eyePosition;

    return transform;

}
#pragma clang diagnostic pop

@end
