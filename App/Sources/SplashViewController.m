#import "SplashViewController.h"
#import "NopticoreTheme.h"
#import "LogoView.h"
#import "Localization.h"

@interface SplashViewController ()
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) LogoView *logoView;
@property (nonatomic, strong) UILabel *wordmarkLabel;
@property (nonatomic, strong) UILabel *taglineLabel;
@end

@implementation SplashViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.gradientLayer = [NopticoreTheme brandGradientLayer];
    [self.view.layer insertSublayer:self.gradientLayer atIndex:0];

    self.logoView = [[LogoView alloc] init];
    self.logoView.strokeColor = [UIColor whiteColor];
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoView.alpha = 0;
    self.logoView.transform = CGAffineTransformMakeScale(0.7, 0.7);
    [self.view addSubview:self.logoView];

    UILabel *wordmark = [[UILabel alloc] init];
    wordmark.text = @"Nopticore";
    wordmark.textColor = [UIColor whiteColor];
    wordmark.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    wordmark.alpha = 0;
    wordmark.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:wordmark];

    UILabel *tagline = [[UILabel alloc] init];
    tagline.text = NPL(@"splash.tagline");
    tagline.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.75];
    tagline.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    tagline.alpha = 0;
    tagline.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tagline];

    [NSLayoutConstraint activateConstraints:@[
        [self.logoView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.logoView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [self.logoView.widthAnchor constraintEqualToConstant:112],
        [self.logoView.heightAnchor constraintEqualToConstant:112],

        [wordmark.topAnchor constraintEqualToAnchor:self.logoView.bottomAnchor constant:22],
        [wordmark.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        [tagline.topAnchor constraintEqualToAnchor:wordmark.bottomAnchor constant:6],
        [tagline.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];

    self.wordmarkLabel = wordmark;
    self.taglineLabel = tagline;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.gradientLayer.frame = self.view.bounds;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self runIntroAnimation];
}

- (void)runIntroAnimation {
    [UIView animateWithDuration:0.55
                          delay:0.05
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.logoView.alpha = 1;
        self.logoView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.4 delay:0.35 options:0 animations:^{
        self.wordmarkLabel.alpha = 1;
    } completion:nil];

    [UIView animateWithDuration:0.4 delay:0.5 options:0 animations:^{
        self.taglineLabel.alpha = 1;
    } completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.onFinished) self.onFinished();
    });
}

@end
