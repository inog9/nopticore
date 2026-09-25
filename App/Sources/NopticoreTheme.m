#import "NopticoreTheme.h"

@implementation NopticoreTheme

+ (UIColor *)colorWithHex:(uint32_t)hex {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                            green:((hex >> 8) & 0xFF) / 255.0
                             blue:(hex & 0xFF) / 255.0
                            alpha:1.0];
}

+ (UIColor *)purpleLight { return [self colorWithHex:0xA78BFA]; }
+ (UIColor *)purple      { return [self colorWithHex:0x7C3AED]; }
+ (UIColor *)purpleDeep  { return [self colorWithHex:0x4C1D95]; }
+ (UIColor *)success     { return [self colorWithHex:0x34C759]; }
+ (UIColor *)warning     { return [self colorWithHex:0xFF9F0A]; }

+ (UIColor *)groupedBackground {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemGroupedBackgroundColor];
    }
    return [UIColor colorWithWhite:0.95 alpha:1.0];
}

+ (UIColor *)cardBackground {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondarySystemGroupedBackgroundColor];
    }
    return [UIColor whiteColor];
}

+ (UIColor *)primaryLabel {
    if (@available(iOS 13.0, *)) {
        return [UIColor labelColor];
    }
    return [UIColor blackColor];
}

+ (UIColor *)secondaryLabel {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondaryLabelColor];
    }
    return [UIColor darkGrayColor];
}

+ (CAGradientLayer *)brandGradientLayer {
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.colors = @[
        (id)[self purpleLight].CGColor,
        (id)[self purple].CGColor,
        (id)[self purpleDeep].CGColor
    ];
    layer.locations = @[@0.0, @0.55, @1.0];
    layer.startPoint = CGPointMake(0, 0);
    layer.endPoint = CGPointMake(1, 1);
    return layer;
}

@end
