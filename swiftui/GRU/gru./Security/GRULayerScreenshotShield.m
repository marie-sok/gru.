#import "GRULayerScreenshotShield.h"
#import <UIKit/UIKit.h>

static UITextField *GRUSharedSecureTextField(void) {
    static UITextField *textField = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        textField = [[UITextField alloc] initWithFrame:CGRectZero];
        textField.text = @" ";
        textField.secureTextEntry = YES;
        textField.userInteractionEnabled = NO;
        textField.hidden = NO;
        [textField setNeedsLayout];
        [textField layoutIfNeeded];
    });
    return textField;
}

static BOOL GRUIsSecureCanvasView(UIView *view) {
    NSString *className = NSStringFromClass(view.class);
    return [className containsString:@"TextLayoutCanvasView"] ||
           [className containsString:@"LayoutCanvasView"];
}

static UIView * _Nullable GRUFindSecureCanvas(UIView *root) {
    for (UIView *subview in root.subviews) {
        if (GRUIsSecureCanvasView(subview)) {
            return subview;
        }

        UIView *nested = GRUFindSecureCanvas(subview);
        if (nested != nil) {
            return nested;
        }
    }
    return nil;
}

@implementation GRULayerScreenshotShield

- (NSNumber *)protectLayer:(CALayer *)layer {
    if (layer == nil || !NSThread.isMainThread) {
        return @NO;
    }

    UITextField *textField = GRUSharedSecureTextField();
    UIView *secureView = GRUFindSecureCanvas(textField);

    // UIKit can build the secure canvas lazily. Toggle once and retry discovery
    // rather than ever exposing the chat through an unprotected fallback.
    if (secureView == nil) {
        textField.secureTextEntry = NO;
        textField.secureTextEntry = YES;
        [textField setNeedsLayout];
        [textField layoutIfNeeded];
        secureView = GRUFindSecureCanvas(textField);
    }

    if (secureView == nil) {
        return @NO;
    }

    CALayer *previousLayer = secureView.layer;
    __block BOOL applied = NO;

    @try {
        // Temporarily substitute the target layer into the secure text canvas.
        // The secureTextEntry transition marks that exact layer as protected by
        // the system capture pipeline. Restore the canvas immediately after.
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

    return @(applied);
}

@end
