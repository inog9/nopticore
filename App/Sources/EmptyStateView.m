#import "EmptyStateView.h"
#import "NopticoreTheme.h"

@implementation EmptyStateView

- (instancetype)initWithSymbolName:(NSString *)symbolName
                              title:(NSString *)title
                           subtitle:(NSString *)subtitle {
    self = [super init];
    if (self) {
        UIView *badge = [[UIView alloc] init];
        badge.backgroundColor = [[NopticoreTheme purple] colorWithAlphaComponent:0.12];
        badge.layer.cornerRadius = 34;
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:badge];

        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.tintColor = [NopticoreTheme purple];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightMedium];
            iconView.image = [[UIImage systemImageNamed:symbolName] imageByApplyingSymbolConfiguration:cfg];
        }
        [badge addSubview:iconView];

        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        titleLabel.textColor = [NopticoreTheme primaryLabel];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:titleLabel];

        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.text = subtitle;
        subtitleLabel.font = [UIFont systemFontOfSize:13];
        subtitleLabel.textColor = [NopticoreTheme secondaryLabel];
        subtitleLabel.textAlignment = NSTextAlignmentCenter;
        subtitleLabel.numberOfLines = 0;
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:subtitleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [badge.topAnchor constraintEqualToAnchor:self.topAnchor constant:24],
            [badge.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [badge.widthAnchor constraintEqualToConstant:68],
            [badge.heightAnchor constraintEqualToConstant:68],

            [iconView.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
            [iconView.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:32],
            [iconView.heightAnchor constraintEqualToConstant:32],

            [titleLabel.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:16],
            [titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:32],
            [titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-32],

            [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6],
            [subtitleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:32],
            [subtitleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-32],
            [subtitleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-24],
        ]];
    }
    return self;
}

@end
