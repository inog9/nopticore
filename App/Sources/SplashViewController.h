#import <UIKit/UIKit.h>

// Layar pembuka bermerek: gradient ungu penuh layar, logo animasi masuk,
// wordmark + tagline. Memanggil onFinished setelah animasi selesai supaya
// AppDelegate bisa pindah ke tab bar utama dengan transisi crossfade.
@interface SplashViewController : UIViewController

@property (nonatomic, copy) void (^onFinished)(void);

@end
