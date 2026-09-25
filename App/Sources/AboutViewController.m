#import "AboutViewController.h"
#import "NopticoreTheme.h"
#import "LogoView.h"
#import "Localization.h"

typedef NS_ENUM(NSInteger, AboutSection) {
    AboutSectionLanguage = 0,
    AboutSectionDescription,
    AboutSectionLinks,
    AboutSectionCount
};

static NSString * const kGitHubURL = @"https://github.com/inog9/nopticore";

@interface AboutViewController ()
@property (nonatomic, strong) UISegmentedControl *languageControl;
@end

@implementation AboutViewController

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
    [self buildHeader];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(languageDidChange)
                                                  name:NPLanguageDidChangeNotification
                                                object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)languageDidChange {
    self.title = NPL(@"tab.about");
    [self.tableView reloadData];
}

- (void)buildHeader {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 190)];

    LogoView *logo = [[LogoView alloc] init];
    logo.strokeColor = [NopticoreTheme purple];
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:logo];

    UILabel *wordmark = [[UILabel alloc] init];
    wordmark.text = @"Nopticore";
    wordmark.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    wordmark.textColor = [NopticoreTheme primaryLabel];
    wordmark.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:wordmark];

    UILabel *tagline = [[UILabel alloc] init];
    tagline.text = NPL(@"about.tagline");
    tagline.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    tagline.textColor = [NopticoreTheme secondaryLabel];
    tagline.textAlignment = NSTextAlignmentCenter;
    tagline.numberOfLines = 2;
    tagline.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:tagline];

    NSString *shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.1.0";
    UILabel *version = [[UILabel alloc] init];
    version.text = [NSString stringWithFormat:NPL(@"about.version"), shortVersion];
    version.font = [UIFont systemFontOfSize:11];
    version.textColor = [NopticoreTheme secondaryLabel];
    version.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:version];

    [NSLayoutConstraint activateConstraints:@[
        [logo.topAnchor constraintEqualToAnchor:container.topAnchor constant:16],
        [logo.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [logo.widthAnchor constraintEqualToConstant:64],
        [logo.heightAnchor constraintEqualToConstant:64],

        [wordmark.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:12],
        [wordmark.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],

        [tagline.topAnchor constraintEqualToAnchor:wordmark.bottomAnchor constant:4],
        [tagline.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:32],
        [tagline.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-32],

        [version.topAnchor constraintEqualToAnchor:tagline.bottomAnchor constant:8],
        [version.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
    ]];

    self.tableView.tableHeaderView = container;
}

#pragma mark - Language row

- (UITableViewCell *)languageCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (!self.languageControl) {
        self.languageControl = [[UISegmentedControl alloc] initWithItems:@[@"Indonesia", @"English"]];
        self.languageControl.selectedSegmentIndex = [[Localization currentLanguage] isEqualToString:@"en"] ? 1 : 0;
        if (@available(iOS 13.0, *)) {
            self.languageControl.selectedSegmentTintColor = [NopticoreTheme purple];
        }
        [self.languageControl addTarget:self action:@selector(languageChanged) forControlEvents:UIControlEventValueChanged];
    }
    self.languageControl.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:self.languageControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.languageControl.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
        [self.languageControl.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
        [self.languageControl.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
        [self.languageControl.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
    ]];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)languageChanged {
    NSString *lang = self.languageControl.selectedSegmentIndex == 1 ? @"en" : @"id";
    [Localization setLanguage:lang];
    if (@available(iOS 10.0, *)) {
        [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return AboutSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case AboutSectionLanguage: return NPL(@"about.section.language");
        case AboutSectionDescription: return NPL(@"about.section.description");
        case AboutSectionLinks: return NPL(@"about.section.links");
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == AboutSectionLanguage) {
        return [self languageCell];
    }

    if (indexPath.section == AboutSectionDescription) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = NPL(@"about.description");
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        cell.textLabel.textColor = [NopticoreTheme secondaryLabel];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    // Links
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = NPL(@"about.link.github");
    cell.textLabel.textColor = [NopticoreTheme purple];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == AboutSectionLinks) {
        NSURL *url = [NSURL URLWithString:kGitHubURL];
        if (url) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
}

@end
