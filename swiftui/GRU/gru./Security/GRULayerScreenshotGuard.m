#import "GRULayerScreenshotGuard.h"

BOOL GRUSetLayerDisableScreenshots(CALayer *layer, BOOL disableScreenshots) {
    static UITextField *textField = nil;
    static UIView *secureView = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        textField = [[UITextField alloc] init];

        for (UIView *subview in textField.subviews) {
            if ([NSStringFromClass([subview class]) containsString:@"TextLayoutCanvasView"]) {
                secureView = subview;
                break;
            }
        }
    });

    if (secureView == nil) {
        return NO;
    }

    CALayer *previousLayer = secureView.layer;

    [secureView setValue:layer forKey:@"layer"];

    if (disableScreenshots) {
        textField.secureTextEntry = NO;
        textField.secureTextEntry = YES;
    } else {
        textField.secureTextEntry = YES;
        textField.secureTextEntry = NO;
    }

    [secureView setValue:previousLayer forKey:@"layer"];

    return YES;
}
