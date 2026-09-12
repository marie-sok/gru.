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

        if (secureView == nil) {
            NSMutableArray<NSString *> *classNames = [[NSMutableArray alloc] init];
            for (UIView *subview in textField.subviews) {
                [classNames addObject:NSStringFromClass([subview class])];
            }
            NSLog(@"[GRUPrivacy] secure layer guard unavailable; UITextField subviews=%@", classNames);
        } else {
            NSLog(@"[GRUPrivacy] secure layer guard canvas=%@", NSStringFromClass([secureView class]));
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

    NSLog(@"[GRUPrivacy] secure layer guard %@", disableScreenshots ? @"enabled" : @"disabled");
    return YES;
}
