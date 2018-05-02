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

// Listing 7.18
@property (nonatomic, strong) NSMutableDictionary *codeLayers;

@end

@implementation THPreviewView

+ (Class)layerClass {

    // Listing 7.18

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

    // Listing 7.18
    _codeLayers = [NSMutableDictionary dictionary];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;

}

- (AVCaptureSession*)session {

    // Listing 7.18
    return self.previewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session {

    // Listing 7.18
    self.previewLayer.session = session;

}

- (AVCaptureVideoPreviewLayer *)previewLayer {

    // Listing 7.18

    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (void)didDetectCodes:(NSArray *)codes {

    // Listing 7.19
    NSArray *transformCodes = [self transformedCodesFromCodes:codes];

    // Listing 7.20
    NSMutableArray *loseKeys = [[self.codeLayers allKeys] mutableCopy];
    for (AVMetadataMachineReadableCodeObject *obj in transformCodes) {
        NSString *value = obj.stringValue;
        if (value) {
            [loseKeys removeObject:value];
        } else {
            continue;
        }
        
        NSArray *layers = _codeLayers[value];
        if (!layers) {
            layers = @[[self makeBoundsLayer], [self makeCornersLayer]];
            
            [[self previewLayer] addSublayer:layers[0]];
            [[self previewLayer] addSublayer:layers[1]];
            _codeLayers[value] = layers;
        }
        CAShapeLayer *bundsLayer = layers[0];
        bundsLayer.path = [self bezierPathForBounds:obj.bounds].CGPath;
        NSLog(@"value: %@", value);
    }
    
    for (NSArray *loseKey in loseKeys) {
        for (CALayer *layer in _codeLayers[loseKey]) {
            [layer removeFromSuperlayer];
        }
        [self.codeLayers removeObjectForKey:loseKey];
    }

    // Listing 7.21
}

- (NSArray *)transformedCodesFromCodes:(NSArray *)codes {

    // Listing 7.19
    NSMutableArray *transformCodes = [NSMutableArray array];
    for (AVMetadataObject *object in codes) {
        AVMetadataObject *obj = [self.previewLayer transformedMetadataObjectForMetadataObject:object];
        [transformCodes addObject:obj];
    }
    return transformCodes;
}

- (UIBezierPath *)bezierPathForBounds:(CGRect)bounds {

    // Listing 7.20

    return [UIBezierPath bezierPathWithRect:bounds];
}

- (CAShapeLayer *)makeBoundsLayer {

    // Listing 7.20
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.lineWidth = 4;
    layer.strokeColor = [UIColor colorWithRed:0.95 green:0.75 blue:0.06 alpha:1].CGColor;

    return layer;
}

- (CAShapeLayer *)makeCornersLayer {

    // Listing 7.20
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.lineWidth = 2;
    layer.fillColor = [UIColor colorWithRed:0.172 green:0.671 blue:0.428 alpha:1].CGColor;
    layer.strokeColor = [UIColor colorWithRed:0.190 green:0.753 blue:0.489 alpha:0.5].CGColor;

    return layer;
}

- (UIBezierPath *)bezierPathForCorners:(NSArray *)corners {

    // Listing 7.21

    return nil;
}

- (CGPoint)pointForCorner:(NSDictionary *)corner {

    // Listing 7.21

    return CGPointZero;
}

@end
