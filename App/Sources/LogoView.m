#import "LogoView.h"

// Ruang desain acuan (sama dengan file icon 1024x1024), semua ukuran
// di bawah dinyatakan dalam satuan ini lalu diskalakan ke bounds view.
static const CGFloat kDesignSize = 1024.0;
static const CGFloat kOuterRingRadius = 338.0;
static const CGFloat kOuterRingWidth = 14.0;
static const CGFloat kSegmentRingRadius = 250.0;
static const CGFloat kSegmentRingWidth = 62.0;
static const CGFloat kCoreRadius = 92.0;
static const NSInteger kSegmentCount = 6;

@implementation LogoView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        _strokeColor = [UIColor whiteColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setStrokeColor:(UIColor *)strokeColor {
    _strokeColor = strokeColor;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
    CGFloat scale = side / kDesignSize;
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));

    // Cincin tipis terluar.
    CGContextSetStrokeColorWithColor(ctx, [self.strokeColor colorWithAlphaComponent:0.18].CGColor);
    CGContextSetLineWidth(ctx, kOuterRingWidth * scale);
    CGContextAddArc(ctx, center.x, center.y, kOuterRingRadius * scale, 0, 2 * M_PI, 0);
    CGContextStrokePath(ctx);

    // Cincin tersegmen: keliling dibagi pola dash 200 + gap 61.8 pada radius
    // 250 menghasilkan tepat 6 segmen (lihat gen_icon.py, geometri sama).
    CGFloat circumference = 2 * M_PI * kSegmentRingRadius;
    CGFloat segmentAngle = (200.0 / circumference) * 2 * M_PI;
    CGFloat gapAngle = (61.8 / circumference) * 2 * M_PI;

    CGContextSetStrokeColorWithColor(ctx, self.strokeColor.CGColor);
    CGContextSetLineWidth(ctx, kSegmentRingWidth * scale);
    CGFloat angle = -M_PI_2; // mulai dari jam 12
    for (NSInteger i = 0; i < kSegmentCount; i++) {
        CGContextAddArc(ctx, center.x, center.y, kSegmentRingRadius * scale,
                        angle, angle + segmentAngle, 0);
        CGContextStrokePath(ctx);
        angle += segmentAngle + gapAngle;
    }

    // Inti.
    CGContextSetFillColorWithColor(ctx, self.strokeColor.CGColor);
    CGContextAddArc(ctx, center.x, center.y, kCoreRadius * scale, 0, 2 * M_PI, 0);
    CGContextFillPath(ctx);
}

@end
