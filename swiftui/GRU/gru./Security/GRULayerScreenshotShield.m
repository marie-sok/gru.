#import "GRULayerScreenshotShield.h"
#import <UIKit/UIKit.h>

static UITextField * _Nullable GRUSecureTextField = nil;
static UIView * _Nullable GRUSecureCanvasView = nil;

static void GRUPrepareSecureCanvas(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Match UIKit's real secure-text canvas discovery exactly: create a
        // plain UITextField and inspect only its direct children for the
        // TextLayoutCanvasView used by secureTextEntry. Do not accept generic
        // LayoutCanvasView descendants because that can report a false success
        // while leaving the rendered chat capturable.
        GRUSecureTextField = [[UITextField alloc] init];

        for (UIView *subview in GRUSecureTextField.subviews) {
            NSString *className = NSStringFromClass(subview.class);
            if ([className containsString:@"TextLayoutCanvasView"]) {
                GRUSecureCanvasView = subview;
                break;
            }
        }
    });
}

static BOOL GRUProtectExactLayer(CALayer *layer) {
    GRUPrepareSecureCanvas();

    UITextField *textField = GRUSecureTextField;
    UIView *secureView = GRUSecureCanvasView;

    if (layer == nil || textField == nil || secureView == nil) {
        return NO;
    }

    CALayer *previousLayer = secureView.layer;
    __block BOOL applied = NO;

    @try {
        // Temporarily substitute the exact rendered layer into UIKit's secure
        // text canvas, perform the secureTextEntry transition, then restore the
        // original canvas layer. This is deliberately kept on the main thread.
        [secureView setValue:layer forKey:@"layer"];
        textField.secureTextEntry = NO;
        textField.secureTextEntry = YES;
        applied = YES;
    } @catch (__unused NSException *exception) {
        applied = NO;
    } @finally {
        @try {
            [secureView setValue:previousLayer forKey:@"layer"];
        } @catch (__unused NSException *exception) {
            applied = NO;
        }
    }

    return applied;
}

static BOOL GRUProtectRenderedLayerTree(CALayer *layer) {
    if (!GRUProtectExactLayer(layer)) {
        return NO;
    }

    // SwiftUI/UIHostingController can render content through multiple CALayer
    // descendants. Protect the tree that already exists at mount time as well
    // as the dedicated parent layer so text, bubbles and media cannot escape
    // through a separately composited child layer.
    NSArray<CALayer *> *children = [layer.sublayers copy] ?: @[];
    for (CALayer *child in children) {
        if (!GRUProtectRenderedLayerTree(child)) {
            return NO;
        }
    }

    return YES;
}

@implementation GRULayerScreenshotShield

- (NSNumber *)protectLayer:(CALayer *)layer {
    if (layer == nil || !NSThread.isMainThread) {
        return @NO;
    }

    return @(GRUProtectRenderedLayerTree(layer));
}

@end
