#import "AppDelegate.h"
#import "StatusViewController.h"
#import "SettingsViewController.h"
#import "AboutViewController.h"
#import "SplashViewController.h"
#import "NopticoreTheme.h"
#import "Localization.h"

@interface AppDelegate ()
@property (nonatomic, weak) UITabBarItem *statusTabItem;
@property (nonatomic, weak) UITabBarItem *configTabItem;
@property (nonatomic, weak) UITabBarItem *aboutTabItem;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if (@available(iOS 13.0, *)) {
        self.window.tintColor = [NopticoreTheme purple];
    }

    __weak typeof(self) weakSelf = self;
    SplashViewController *splash = [[SplashViewController alloc] init];
    splash.onFinished = ^{
        [weakSelf presentMainInterface];
    };

    self.window.rootViewController = splash;
    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(refreshTabTitles)
                                                  name:NPLanguageDidChangeNotification
                                                object:nil];
    return YES;
}

// Tab bar utama (Status + Config + Info), ditampilkan setelah splash selesai
// lewat crossfade halus -- bukan langsung lompat ke fitur begitu app dibuka.
- (void)presentMainInterface {
    // SF Symbols baru ada di iOS 13+. Di bawah itu tab tetap jalan, cuma
    // tanpa icon -- sengaja tidak menaikkan minimum iOS supaya daemon+app
    // tetap bisa dipasang di device lama (mis. iPad lawas).
    UIImage *statusIcon = nil, *settingsIcon = nil, *aboutIcon = nil;
    if (@available(iOS 13.0, *)) {
        statusIcon = [UIImage systemImageNamed:@"shield.lefthalf.filled"];
        settingsIcon = [UIImage systemImageNamed:@"gearshape"];
        aboutIcon = [UIImage systemImageNamed:@"info.circle"];
    }

    UIViewController *status = [[StatusViewController alloc] init];
    UITabBarItem *statusItem = [[UITabBarItem alloc] initWithTitle:NPL(@"tab.status") image:statusIcon tag:0];
    status.tabBarItem = statusItem;
    self.statusTabItem = statusItem;
    UINavigationController *statusNav = [[UINavigationController alloc] initWithRootViewController:status];

    UIViewController *settings = [[SettingsViewController alloc] init];
    UITabBarItem *configItem = [[UITabBarItem alloc] initWithTitle:NPL(@"tab.config") image:settingsIcon tag:1];
    settings.tabBarItem = configItem;
    self.configTabItem = configItem;
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settings];

    UIViewController *about = [[AboutViewController alloc] init];
    about.title = NPL(@"tab.about");
    UITabBarItem *aboutItem = [[UITabBarItem alloc] initWithTitle:NPL(@"tab.about") image:aboutIcon tag:2];
    about.tabBarItem = aboutItem;
    self.aboutTabItem = aboutItem;
    UINavigationController *aboutNav = [[UINavigationController alloc] initWithRootViewController:about];

    for (UINavigationController *nav in @[statusNav, settingsNav, aboutNav]) {
        nav.navigationBar.prefersLargeTitles = YES;
    }

    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    if (@available(iOS 13.0, *)) {
        tabBarController.tabBar.tintColor = [NopticoreTheme purple];
    }
    tabBarController.viewControllers = @[statusNav, settingsNav, aboutNav];

    [UIView transitionWithView:self.window
                       duration:0.35
                        options:UIViewAnimationOptionTransitionCrossDissolve
                     animations:^{
        self.window.rootViewController = tabBarController;
    } completion:nil];
}

- (void)refreshTabTitles {
    self.statusTabItem.title = NPL(@"tab.status");
    self.configTabItem.title = NPL(@"tab.config");
    self.aboutTabItem.title = NPL(@"tab.about");
}

@end
