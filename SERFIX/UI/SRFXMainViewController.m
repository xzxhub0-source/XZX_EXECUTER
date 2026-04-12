#import "SRFXMainViewController.h"
#import "SRFXScriptBlox.h"
#include "Core/SRFXLua.h"

@interface SRFXMainViewController () <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SRFXMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:0.98];
    self.view.layer.cornerRadius = 16;
    self.view.layer.borderWidth = 1.2;
    self.view.layer.borderColor = [UIColor colorWithRed:0.5 green:0.3 blue:1.0 alpha:1.0].CGColor;

    [self setupHeader];
    [self setupTabBar];
    [self setupEditor];
    [self setupScriptList];
    [self setupConsole];
    [self setupButtons];

    self.scripts = [NSMutableArray array];
    self.consoleText = [NSMutableString string];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePrint:) name:@"SRFXPrint" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleError:) name:@"SRFXError" object:nil];

    [self loadTrendingScripts];
}

- (void)setupHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 55)];
    header.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, header.bounds.size.height - 2, header.bounds.size.width, 2);
    gradient.colors = @[(id)[UIColor colorWithRed:0.5 green:0.3 blue:1.0 alpha:1.0].CGColor,
                        (id)[UIColor colorWithRed:0.3 green:0.2 blue:0.8 alpha:0.0].CGColor];
    gradient.startPoint = CGPointMake(0, 0.5);
    gradient.endPoint = CGPointMake(1, 0.5);
    [header.layer addSublayer:gradient];
    [self.view addSubview:header];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 150, 30)];
    title.text = @"SERFIX";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:22];
    [header addSubview:title];

    UIButton *minimizeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minimizeBtn.frame = CGRectMake(self.view.bounds.size.width - 95, 10, 40, 35);
    [minimizeBtn setTitle:@"−" forState:UIControlStateNormal];
    [minimizeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    minimizeBtn.titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightThin];
    [minimizeBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:minimizeBtn];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.view.bounds.size.width - 50, 10, 40, 35);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:22];
    [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
}

- (void)setupTabBar {
    self.tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, 55, self.view.bounds.size.width, 42)];
    self.tabBar.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.10 alpha:1.0];
    [self.view addSubview:self.tabBar];

    NSArray *tabs = @[@"Editor", @"ScriptBlox", @"Console", @"Settings"];
    for (int i = 0; i < tabs.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(i * (self.view.bounds.size.width / tabs.count), 0,
                               self.view.bounds.size.width / tabs.count, 42);
        [btn setTitle:tabs[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        btn.tag = i;
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabBar addSubview:btn];
    }

    self.selectedTab = 0;
    [self updateTabSelection];
}

- (void)setupEditor {
    CGFloat y = 97;
    self.editor = [[UITextView alloc] initWithFrame:CGRectMake(10, y, self.view.bounds.size.width - 20, self.view.bounds.size.height - y - 85)];
    self.editor.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.09 alpha:1.0];
    self.editor.textColor = [UIColor colorWithRed:0.9 green:0.9 blue:1.0 alpha:1.0];
    self.editor.font = [UIFont fontWithName:@"Menlo" size:13];
    self.editor.text = @"-- SERFIX Executor\nprint('Hello World!')";
    self.editor.autocorrectionType = UITextAutocorrectionTypeNo;
    self.editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.editor.smartQuotesType = UITextSmartQuotesTypeNo;
    self.editor.layer.borderColor = [UIColor colorWithRed:0.4 green:0.2 blue:0.9 alpha:0.5].CGColor;
    self.editor.layer.borderWidth = 1;
    self.editor.layer.cornerRadius = 8;
    self.editor.delegate = self;
    [self.view addSubview:self.editor];
}

- (void)setupScriptList {
    self.scriptList = [[UITableView alloc] initWithFrame:self.editor.frame style:UITableViewStylePlain];
    self.scriptList.backgroundColor = self.editor.backgroundColor;
    self.scriptList.delegate = self;
    self.scriptList.dataSource = self;
    self.scriptList.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.scriptList.hidden = YES;
    self.scriptList.rowHeight = 70;
    [self.view addSubview:self.scriptList];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(10, 97, self.view.bounds.size.width - 20, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search ScriptBlox...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.searchTextField.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    self.searchBar.searchTextField.textColor = [UIColor whiteColor];
    self.searchBar.hidden = YES;
    [self.view addSubview:self.searchBar];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 200);
    self.spinner.color = [UIColor colorWithRed:0.5 green:0.3 blue:1.0 alpha:1.0];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
}

- (void)setupConsole {
    self.consoleView = [[UITextView alloc] initWithFrame:self.editor.frame];
    self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];
    self.consoleView.textColor = [UIColor colorWithRed:0.5 green:1.0 blue:0.5 alpha:1.0];
    self.consoleView.font = [UIFont fontWithName:@"Menlo" size:12];
    self.consoleView.editable = NO;
    self.consoleView.hidden = YES;
    self.consoleView.layer.cornerRadius = 8;
    [self.view addSubview:self.consoleView];
}

- (void)setupButtons {
    UIButton *execBtn = [self createButton:@"Execute" frame:CGRectMake(10, self.view.bounds.size.height - 75, 95, 42)
                                     color:[UIColor colorWithRed:0.4 green:0.3 blue:1.0 alpha:1.0]
                                     action:@selector(execute)];
    [self.view addSubview:execBtn];

    UIButton *clearBtn = [self createButton:@"Clear" frame:CGRectMake(115, self.view.bounds.size.height - 75, 95, 42)
                                      color:[UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0]
                                      action:@selector(clear)];
    [self.view addSubview:clearBtn];

    UIButton *loadBtn = [self createButton:@"Load" frame:CGRectMake(220, self.view.bounds.size.height - 75, 95, 42)
                                     color:[UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1.0]
                                     action:@selector(showScriptBlox)];
    [self.view addSubview:loadBtn];
}

- (UIButton *)createButton:(NSString *)title frame:(CGRect)frame color:(UIColor *)color action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.backgroundColor = color;
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    btn.layer.cornerRadius = 8;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)loadTrendingScripts {
    [self.spinner startAnimating];
    [SRFXScriptBlox fetchTrending:^(NSArray *scripts) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scripts removeAllObjects];
            [self.scripts addObjectsFromArray:scripts];
            [self.scriptList reloadData];
            [self.spinner stopAnimating];
        });
    }];
}

- (void)tabTapped:(UIButton *)sender {
    self.selectedTab = sender.tag;
    [self updateTabSelection];
}

- (void)updateTabSelection {
    for (UIView *v in self.tabBar.subviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            UIButton *b = (UIButton *)v;
            [b setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        }
    }
    UIButton *selected = (UIButton *)[self.tabBar viewWithTag:self.selectedTab];
    [selected setTitleColor:[UIColor colorWithRed:0.5 green:0.3 blue:1.0 alpha:1.0] forState:UIControlStateNormal];

    self.editor.hidden = (self.selectedTab != 0);
    self.scriptList.hidden = (self.selectedTab != 1);
    self.searchBar.hidden = (self.selectedTab != 1);
    self.consoleView.hidden = (self.selectedTab != 2);

    if (self.selectedTab == 1 && self.scripts.count == 0) {
        [self loadTrendingScripts];
    }

    if (self.selectedTab == 1) {
        self.scriptList.frame = CGRectMake(10, 145, self.view.bounds.size.width - 20, self.view.bounds.size.height - 230);
    } else {
        self.scriptList.frame = self.editor.frame;
    }
}

- (void)showScriptBlox {
    self.selectedTab = 1;
    [self updateTabSelection];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.scripts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];

        UIView *bg = [[UIView alloc] init];
        bg.backgroundColor = [UIColor colorWithRed:0.3 green:0.2 blue:0.6 alpha:0.4];
        cell.selectedBackgroundView = bg;
    }

    NSDictionary *s = self.scripts[indexPath.row];
    cell.textLabel.text = s[@"title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"By %@  •  %@", s[@"author"], s[@"game"]];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *s = self.scripts[indexPath.row];
    NSString *slug = s[@"slug"];
    [self.spinner startAnimating];
    [SRFXScriptBlox fetchScript:slug completion:^(NSString *code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.editor.text = code;
            self.selectedTab = 0;
            [self updateTabSelection];
            [self.spinner stopAnimating];
        });
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self.spinner startAnimating];
    [SRFXScriptBlox search:searchBar.text completion:^(NSArray *results) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scripts removeAllObjects];
            [self.scripts addObjectsFromArray:results];
            [self.scriptList reloadData];
            [self.spinner stopAnimating];
        });
    }];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [self loadTrendingScripts];
}

- (void)handlePrint:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.consoleText appendFormat:@"%@\n", note.object];
        self.consoleView.text = self.consoleText;
        if (self.consoleText.length > 10000) {
            self.consoleText = [[self.consoleText substringFromIndex:self.consoleText.length - 5000] mutableCopy];
        }
    });
}

- (void)handleError:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.consoleText appendFormat:@"[ERROR] %@\n", note.object];
        self.consoleView.text = self.consoleText;
    });
}

- (void)execute {
    if (self.editor.text.length > 0) {
        SRFXLuaExecute(self.editor.text.UTF8String);
    }
}

- (void)clear {
    self.editor.text = @"";
    self.consoleText = [NSMutableString string];
    self.consoleView.text = @"";
}

- (void)hide {
    self.view.window.hidden = YES;
}

- (void)minimize {
    self.view.window.frame = CGRectMake(self.view.window.frame.origin.x,
                                         self.view.window.frame.origin.y,
                                         55, 55);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
