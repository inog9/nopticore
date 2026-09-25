#import <UIKit/UIKit.h>

// Kartu status besar di atas daftar -- ringkasan sekali lihat: daemon sehat
// atau tidak, dan kapan terakhir lapor.
@interface StatusHeaderView : UIView

- (void)configureWithHealthy:(BOOL)healthy
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle;

// tableHeaderView butuh tinggi eksplisit; hitung dari Auto Layout.
- (CGFloat)preferredHeightForWidth:(CGFloat)width;

@end
