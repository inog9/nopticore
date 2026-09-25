#import <UIKit/UIKit.h>

// Satu sumber kebenaran untuk warna & spacing, supaya splash, onboarding,
// dan layar utama konsisten.
@interface NopticoreTheme : NSObject

+ (UIColor *)purpleLight;   // #A78BFA
+ (UIColor *)purple;        // #7C3AED -- warna tint utama app
+ (UIColor *)purpleDeep;    // #4C1D95

+ (UIColor *)success;
+ (UIColor *)warning;

// Background adaptif: pakai system grouped background di iOS 13+, fallback
// warna statis di bawahnya supaya tidak crash di device lama.
+ (UIColor *)groupedBackground;
+ (UIColor *)cardBackground;
+ (UIColor *)primaryLabel;
+ (UIColor *)secondaryLabel;

// Layer gradient ungu diagonal, dipakai splash & onboarding.
+ (CAGradientLayer *)brandGradientLayer;

@end
