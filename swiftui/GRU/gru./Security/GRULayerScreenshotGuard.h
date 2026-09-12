#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

/// Marks an existing CALayer as capture-protected using UIKit's secure text
/// compositor behavior. Returns NO when UIKit's secure canvas is unavailable.
FOUNDATION_EXPORT BOOL GRUSetLayerDisableScreenshots(CALayer *layer, BOOL disableScreenshots);

NS_ASSUME_NONNULL_END
