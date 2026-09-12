#import "GRULayerScreenshotGuard.h"

static UIView *GRUFindSecureCanvas(UIView *root) {
    if (root == nil) {
        return nil;
    }

    NSString *className = NSStringFromClass([root class]);
    if ([className containsString:@"TextLayoutCanvasView"] ||
        [className containsString:@"TextFieldCanvasView"]) {
        return root;
    }

    for (UIView *subview in root.subviews) {
        UIView *match = GRUFindSecureCanvas(subview);
        if (match != nil) {
            return match;
        }
    }

    return nil;
}

static void GRUCollectViewClasses(UIView *root, NSMutableArray<NSString *> *classes) {
    if (root == nil) {
        return;
    }

    [classes addObject:NSStringFromClass([root class])];
    for (UIView *subview in root.subviews) {
        GRUCollectViewClasses(subview, classes);
    }
}

BOOL GRUSetLayerDisableScreenshots(CALayer *layer, BOOL disableScreenshots) {
    static UITextField *textField = nil;
    static UIView *secureView = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        textField = [[UITextField alloc] initWithFrame:CGRectMake(0.0, 0.0, 2.0, 2.0)];
        textField.text = @" ";
        textField.textColor = UIColor.clearColor;
        textField.tintColor = UIColor.clearColor;
        textField.backgroundColor = UIColor.clearColor;

        // Force UIKit to instantiate its secure-text rendering subtree before
        // resolving the internal canvas. This field never becomes first responder.
        textField.secureTextEntry = NO;
        [textField setNeedsLayout];
        [textField layoutIfNeeded];
        textField.secureTextEntry = YES;
        [textField setNeedsLayout];
        [textField layoutIfNeeded];

        secureView = GRUFindSecureCanvas(textField);

        if (secureView == nil) {
            NSMutableArray<NSString *> *classNames = [[NSMutableArray alloc] init];
            GRUCollectViewClasses(textField, classNames);
            NSLog(@"[GRUPrivacy] secure layer guard unavailable; UITextField hierarchy=%@", classNames);
        } else {
            NSLog(@"[GRUPrivacy] secure layer guard canvas=%@", NSStringFromClass([secureView class]));
        }
    });

    if (secureView == nil || layer == nil) {
        return NO;
    }

    CALayer *previousLayer = secureView.layer;

    @try {
        [secureView setValue:layer forKey:@"layer"];

        if (disableScreenshots) {
            textField.secureTextEntry = NO;
            [textField setNeedsLayout];
            [textField layoutIfNeeded];
            textField.secureTextEntry = YES;
        } else {
            textField.secureTextEntry = YES;
            textField.secureTextEntry = NO;
        }

        [textField setNeedsLayout];
        [textField layoutIfNeeded];
    } @finally {
        [secureView setValue:previousLayer forKey:@"layer"];
    }

    NSLog(@"[GRUPrivacy] secure layer guard %@", disableScreenshots ? @"enabled" : @"disabled");
    return YES;
}
