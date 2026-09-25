#import <UIKit/UIKit.h>

// Empty state generik: icon bulat berwarna + judul + subjudul. Dipakai saat
// daemon belum pernah jalan (belum ada log buat ditampilkan).
@interface EmptyStateView : UIView

- (instancetype)initWithSymbolName:(NSString *)symbolName
                              title:(NSString *)title
                           subtitle:(NSString *)subtitle;

@end
