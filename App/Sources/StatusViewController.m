#import "StatusViewController.h"
#import "DaemonStatus.h"
#import "AppConfigStore.h"
#import "NopticoreTheme.h"
#import "EmptyStateView.h"
#import "Localization.h"
#import <sys/utsname.h>

typedef NS_ENUM(NSInteger, StatusSection) {
    StatusSectionDevice = 0,
    StatusSectionDaemon,
    StatusSectionRecentLog,
    StatusSectionCount
};

// Baris info sederhana: judul, nilai, dan nama SF Symbol + warna badge-nya.
@interface StatusRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, strong) UIColor *tintColor;
+ (instancetype)rowWithTitle:(NSString *)title value:(NSString *)value symbol:(NSString *)symbol tint:(UIColor *)tint;
@end

@implementation StatusRow
+ (instancetype)rowWithTitle:(NSString *)title value:(NSString *)value symbol:(NSString *)symbol tint:(UIColor *)tint {
    StatusRow *row = [[StatusRow alloc] init];
    row.title = title;
    row.value = value;
    row.symbolName = symbol;
    row.tintColor = tint;
    return row;
}
@end

@interface StatusViewController ()
@property (nonatomic, strong) NSArray<StatusRow *> *deviceRows;
@property (nonatomic, strong) NSArray<StatusRow *> *daemonRows;
@property (nonatomic, strong) NSArray<NSString *> *logLines;
@property (nonatomic, assign) BOOL daemonNeverRan;
@property (nonatomic, strong) UIView *healthHeader;
@property (nonatomic, strong) UILabel *healthTitleLabel;
@property (nonatomic, strong) UILabel *healthSubtitleLabel;
@property (nonatomic, strong) UIView *healthDot;
@end

@implementation StatusViewController

- (instancetype)init {
    UITableViewStyle style = UITableViewStyleGrouped;
    if (@available(iOS 13.0, *)) {
        style = UITableViewStyleInsetGrouped;
    }
    return [super initWithStyle:style];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [NopticoreTheme groupedBackground];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 54;

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reloadData) forControlEvents:UIControlEventValueChanged];

    [self buildHealthHeader];
    [self reloadData];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(reloadData)
                                                  name:NPLanguageDidChangeNotification
                                                object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

#pragma mark - Health hero card

- (void)buildHealthHeader {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 108)];

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [NopticoreTheme cardBackground];
    card.layer.cornerRadius = 18;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:card];

    UIView *dot = [[UIView alloc] init];
    dot.layer.cornerRadius = 6;
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:dot];
    self.healthDot = dot;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    titleLabel.textColor = [NopticoreTheme primaryLabel];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:titleLabel];
    self.healthTitleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.font = [UIFont systemFontOfSize:13];
    subtitleLabel.textColor = [NopticoreTheme secondaryLabel];
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:subtitleLabel];
    self.healthSubtitleLabel = subtitleLabel;

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:container.topAnchor],
        [card.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
        [card.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
        [card.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8],

        [dot.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [dot.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [dot.widthAnchor constraintEqualToConstant:12],
        [dot.heightAnchor constraintEqualToConstant:12],

        [titleLabel.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];

    self.healthHeader = container;
    self.tableView.tableHeaderView = container;
}

- (void)updateHealthHeaderHealthy:(BOOL)healthy subtitle:(NSString *)subtitle {
    UIColor *color = healthy ? [NopticoreTheme success] : [NopticoreTheme warning];
    self.healthDot.backgroundColor = color;
    self.healthTitleLabel.text = healthy ? NPL(@"status.health.active.title") : NPL(@"status.health.needsCheck.title");
    self.healthSubtitleLabel.text = subtitle;
}

#pragma mark - Data

- (NSString *)persistentDeviceID {
    NSString *path = @"/var/mobile/Library/Preferences/com.ptxyz.nopticore.device_id";
    NSString *value = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : NPL(@"status.row.deviceId.none");
}

- (void)reloadData {
    self.title = NPL(@"status.title");

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    self.deviceRows = @[
        [StatusRow rowWithTitle:NPL(@"status.row.model") value:machine symbol:@"iphone" tint:[NopticoreTheme purple]],
        [StatusRow rowWithTitle:NPL(@"status.row.ios") value:[UIDevice currentDevice].systemVersion symbol:@"gear" tint:[UIColor systemGrayColor]],
        [StatusRow rowWithTitle:NPL(@"status.row.deviceId") value:[self persistentDeviceID] symbol:@"number" tint:[UIColor systemBlueColor]],
    ];

    NSDictionary *config = [AppConfigStore load];
    BOOL installed = [DaemonStatus isLaunchDaemonInstalled];
    NSDate *lastActivity = [DaemonStatus lastLogActivity];
    NSString *lastActivityStr = @"--";
    BOOL recentlyActive = NO;
    if (lastActivity) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateStyle = NSDateFormatterMediumStyle;
        fmt.timeStyle = NSDateFormatterShortStyle;
        lastActivityStr = [fmt stringFromDate:lastActivity];
        recentlyActive = [[NSDate date] timeIntervalSinceDate:lastActivity] < 900; // 15 menit
    }

    BOOL healthy = installed && recentlyActive;
    NSString *subtitle;
    if (!installed) {
        subtitle = NPL(@"status.health.notInstalled");
    } else if (!recentlyActive) {
        subtitle = [NSString stringWithFormat:NPL(@"status.health.lastReportStale"), lastActivityStr];
    } else {
        subtitle = [NSString stringWithFormat:NPL(@"status.health.lastReport"), lastActivityStr];
    }
    [self updateHealthHeaderHealthy:healthy subtitle:subtitle];

    self.daemonRows = @[
        [StatusRow rowWithTitle:NPL(@"status.row.launchDaemon")
                           value:installed ? NPL(@"status.row.launchDaemon.installed") : NPL(@"status.row.launchDaemon.notFound")
                          symbol:@"bolt.fill" tint:installed ? [NopticoreTheme success] : [NopticoreTheme warning]],
        [StatusRow rowWithTitle:NPL(@"status.row.backendUrl") value:config[@"backend_url"] ?: NPL(@"status.row.backendUrl.unset")
                          symbol:@"network" tint:[UIColor systemTealColor]],
        [StatusRow rowWithTitle:NPL(@"status.row.tier") value:config[@"tier"] ?: @"full"
                          symbol:@"square.stack.3d.up.fill" tint:[UIColor systemIndigoColor]],
        [StatusRow rowWithTitle:NPL(@"status.row.interval")
                           value:[NSString stringWithFormat:NPL(@"status.row.interval.value"), config[@"interval"] ?: @"300"]
                          symbol:@"timer" tint:[UIColor systemOrangeColor]],
    ];

    self.logLines = [DaemonStatus recentLogLines:8];
    self.daemonNeverRan = (self.logLines.count == 0);

    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return StatusSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case StatusSectionDevice: return self.deviceRows.count;
        case StatusSectionDaemon: return self.daemonRows.count;
        case StatusSectionRecentLog: return self.daemonNeverRan ? 1 : self.logLines.count;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case StatusSectionDevice: return NPL(@"status.section.device");
        case StatusSectionDaemon: return NPL(@"status.section.daemon");
        case StatusSectionRecentLog: return NPL(@"status.section.log");
        default: return nil;
    }
}

// Badge icon bulat berwarna, gaya app Settings iOS -- dipakai baik lewat
// UIListContentConfiguration (iOS 14+) maupun fallback imageView manual.
- (UIImage *)badgeImageForSymbol:(NSString *)symbolName tint:(UIColor *)tint {
    if (@available(iOS 13.0, *)) {} else { return nil; } // SF Symbols baru ada di iOS 13+
    CGFloat side = 28;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
        CGRect rect = CGRectMake(0, 0, side, side);
        [tint setFill];
        [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:7] fill];

        if (@available(iOS 13.0, *)) {
            UIImage *symbol = [UIImage systemImageNamed:symbolName];
            if (symbol) {
                UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
                symbol = [symbol imageByApplyingSymbolConfiguration:cfg];
                symbol = [symbol imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                CGFloat inset = (side - 16) / 2.0;
                [symbol drawInRect:CGRectInset(rect, inset, inset)];
            }
        }
    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseID = @"cell";
    static NSString *logReuseID = @"logCell";
    static NSString *emptyReuseID = @"emptyCell";

    if (indexPath.section == StatusSectionRecentLog) {
        if (self.daemonNeverRan) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:emptyReuseID];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:emptyReuseID];
            }
            for (UIView *sub in cell.contentView.subviews) [sub removeFromSuperview];
            EmptyStateView *empty = [[EmptyStateView alloc] initWithSymbolName:@"tray"
                                                                           title:NPL(@"status.empty.title")
                                                                        subtitle:NPL(@"status.empty.subtitle")];
            empty.translatesAutoresizingMaskIntoConstraints = NO;
            [cell.contentView addSubview:empty];
            [NSLayoutConstraint activateConstraints:@[
                [empty.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
                [empty.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
                [empty.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
                [empty.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
            ]];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }

        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:logReuseID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:logReuseID];
            cell.textLabel.numberOfLines = 0;
        }
        cell.textLabel.text = self.logLines[indexPath.row];
        if (@available(iOS 13.0, *)) {
            cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
            cell.textLabel.textColor = [UIColor secondaryLabelColor];
        } else {
            cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
            cell.textLabel.textColor = [UIColor grayColor];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    StatusRow *row = (indexPath.section == StatusSectionDevice) ? self.deviceRows[indexPath.row] : self.daemonRows[indexPath.row];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseID];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (@available(iOS 14.0, *)) {
        UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
        content.text = row.title;
        content.secondaryText = row.value;
        content.secondaryTextProperties.color = [NopticoreTheme secondaryLabel];
        content.secondaryTextProperties.numberOfLines = 2;
        content.image = [self badgeImageForSymbol:row.symbolName tint:row.tintColor];
        content.imageToTextPadding = 12;
        cell.contentConfiguration = content;
        cell.backgroundColor = [UIColor clearColor];
    } else {
        cell.textLabel.text = row.title;
        cell.detailTextLabel.text = row.value;
        cell.detailTextLabel.textColor = [NopticoreTheme secondaryLabel];
        cell.imageView.image = [self badgeImageForSymbol:row.symbolName tint:row.tintColor];
    }

    return cell;
}

@end
