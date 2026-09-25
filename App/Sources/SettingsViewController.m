#import "SettingsViewController.h"
#import "AppConfigStore.h"
#import "NopticoreTheme.h"
#import "Localization.h"

@interface SettingsViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *backendURLField;
@property (nonatomic, strong) UITextField *authTokenField;
@property (nonatomic, strong) UISegmentedControl *tierControl;
@property (nonatomic, strong) UITextField *intervalField;
@end

@implementation SettingsViewController

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
    [self buildSaveButton];
    [self loadCurrentValues];
    [self refreshLocalizedText];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(refreshLocalizedText)
                                                  name:NPLanguageDidChangeNotification
                                                object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildSaveButton {
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:NPL(@"config.save")
                                                                     style:UIBarButtonItemStyleDone
                                                                    target:self
                                                                    action:@selector(save)];
    if (@available(iOS 13.0, *)) {
        saveButton.tintColor = [NopticoreTheme purple];
    }
    self.navigationItem.rightBarButtonItem = saveButton;
}

- (void)refreshLocalizedText {
    self.title = NPL(@"config.title");
    self.navigationItem.rightBarButtonItem.title = NPL(@"config.save");
    self.backendURLField.placeholder = @"https://nopticore.ptxyz.tech:8443/ingest/ios";
    self.authTokenField.placeholder = NPL(@"config.row.authToken");
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadCurrentValues];
    [self.tableView reloadData];
}

- (void)loadCurrentValues {
    NSDictionary *config = [AppConfigStore load];
    if (!self.backendURLField) {
        self.backendURLField = [self makeTextFieldWithPlaceholder:@"https://nopticore.ptxyz.tech:8443/ingest/ios"];
        self.backendURLField.keyboardType = UIKeyboardTypeURL;

        self.authTokenField = [self makeTextFieldWithPlaceholder:@"token unik per-device"];

        self.tierControl = [[UISegmentedControl alloc] initWithItems:@[@"full", @"lite"]];
        if (@available(iOS 13.0, *)) {
            self.tierControl.selectedSegmentTintColor = [NopticoreTheme purple];
        }

        self.intervalField = [self makeTextFieldWithPlaceholder:@"300"];
        self.intervalField.keyboardType = UIKeyboardTypeNumberPad;
    }
    self.backendURLField.text = config[@"backend_url"];
    self.authTokenField.text = config[@"auth_token"];
    NSString *tier = config[@"tier"] ?: @"full";
    self.tierControl.selectedSegmentIndex = [tier isEqualToString:@"lite"] ? 1 : 0;
    NSNumber *interval = config[@"interval"] ?: @300;
    self.intervalField.text = [interval stringValue];
}

- (UITextField *)makeTextFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.textAlignment = NSTextAlignmentRight;
    field.font = [UIFont systemFontOfSize:15];
    return field;
}

- (void)save {
    [self.view endEditing:YES];
    NSInteger interval = self.intervalField.text.integerValue;
    if (interval <= 0) interval = 300;
    NSString *tier = self.tierControl.selectedSegmentIndex == 1 ? @"lite" : @"full";

    BOOL ok = [AppConfigStore saveBackendURL:self.backendURLField.text
                                    authToken:self.authTokenField.text
                                         tier:tier
                                     interval:interval];

    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
        [feedback notificationOccurred:ok ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError];
    }

    NSString *title = ok ? NPL(@"config.saved.title") : NPL(@"config.saveFailed.title");
    NSString *message = ok ? NPL(@"config.saved.message") : NPL(@"config.saveFailed.message");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                     message:message
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NPL(@"common.ok") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NPL(@"config.section.header");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return NPL(@"config.section.footer");
}

- (UIImage *)badgeImageForSymbol:(NSString *)symbolName tint:(UIColor *)tint {
    if (![UIImage respondsToSelector:@selector(systemImageNamed:)]) return nil;
    CGFloat side = 28;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
        CGRect rect = CGRectMake(0, 0, side, side);
        [tint setFill];
        [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:7] fill];

        UIImage *symbol = [UIImage systemImageNamed:symbolName];
        if (symbol) {
            UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
            symbol = [symbol imageByApplyingSymbolConfiguration:cfg];
            symbol = [symbol imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
            CGFloat inset = (side - 16) / 2.0;
            [symbol drawInRect:CGRectInset(rect, inset, inset)];
        }
    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseID = @"settingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseID];
    }
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }
    cell.imageView.image = nil;
    cell.contentConfiguration = nil;

    UIView *inputView = nil;
    NSString *label = nil;
    NSString *symbol = nil;
    UIColor *tint = nil;
    switch (indexPath.row) {
        case 0: label = NPL(@"config.row.backendUrl"); inputView = self.backendURLField; symbol = @"network"; tint = [UIColor systemTealColor]; break;
        case 1: label = NPL(@"config.row.authToken"); inputView = self.authTokenField; symbol = @"key.fill"; tint = [UIColor systemYellowColor]; break;
        case 2: label = NPL(@"config.row.tier"); inputView = self.tierControl; symbol = @"square.stack.3d.up.fill"; tint = [UIColor systemIndigoColor]; break;
        case 3: label = NPL(@"config.row.interval"); inputView = self.intervalField; symbol = @"timer"; tint = [UIColor systemOrangeColor]; break;
    }

    if (@available(iOS 14.0, *)) {
        UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
        content.text = label;
        content.image = [self badgeImageForSymbol:symbol tint:tint];
        cell.contentConfiguration = content;
    } else {
        cell.textLabel.text = label;
        cell.imageView.image = [self badgeImageForSymbol:symbol tint:tint];
    }

    inputView.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:inputView];
    [NSLayoutConstraint activateConstraints:@[
        [inputView.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
        [inputView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [inputView.widthAnchor constraintLessThanOrEqualToAnchor:cell.contentView.widthAnchor multiplier:0.52]
    ]];

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end
