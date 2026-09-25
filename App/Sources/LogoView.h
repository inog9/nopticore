#import <UIKit/UIKit.h>

// Logo aperture Nopticore digambar dengan Core Graphics, geometri identik
// dengan app icon. Digambar (bukan PNG) supaya tajam di ukuran berapa pun
// dan warnanya bisa mengikuti konteks (putih di atas ungu, ungu di atas terang).
@interface LogoView : UIView

@property (nonatomic, strong) UIColor *strokeColor;

@end
