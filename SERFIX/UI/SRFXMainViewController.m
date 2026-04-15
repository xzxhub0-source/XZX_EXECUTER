#import "SRFXMainViewController.h"
#import "SRFXScriptBlox.h"
void SRFXLuaExecute(const char *script);

#define SRFX_BG        [UIColor colorWithRed:0.04 green:0.04 blue:0.09 alpha:0.97]
#define SRFX_SURFACE   [UIColor colorWithRed:0.08 green:0.07 blue:0.14 alpha:1.0]
#define SRFX_SURFACE2  [UIColor colorWithRed:0.11 green:0.10 blue:0.18 alpha:1.0]
#define SRFX_PURPLE    [UIColor colorWithRed:0.55 green:0.18 blue:0.79 alpha:1.0]
#define SRFX_PINK      [UIColor colorWithRed:1.00 green:0.12 blue:0.56 alpha:1.0]
#define SRFX_GREEN     [UIColor colorWithRed:0.18 green:0.78 blue:0.45 alpha:1.0]
#define SRFX_BORDER    [UIColor colorWithRed:0.24 green:0.14 blue:0.40 alpha:1.0]
#define SRFX_TEXT      [UIColor colorWithRed:0.92 green:0.88 blue:1.00 alpha:1.0]
#define SRFX_MUTED     [UIColor colorWithRed:0.55 green:0.50 blue:0.68 alpha:1.0]

#define PANEL_W   MIN(UIScreen.mainScreen.bounds.size.width  - 20, 360.0)
#define PANEL_H   MIN(UIScreen.mainScreen.bounds.size.height - 80, 520.0)

@interface SRFXScriptCard : UITableViewCell
@property (nonatomic, strong) UIView   *thumb;
@property (nonatomic, strong) UILabel  *titleLbl;
@property (nonatomic, strong) UILabel  *gameLbl;
@property (nonatomic, strong) UIButton *loadBtn;
- (void)configureWithData:(NSDictionary *)d;
@end

@implementation SRFXScriptCard

- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    self = [super initWithStyle:s reuseIdentifier:r];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = SRFX_SURFACE2;
    self.contentView.layer.cornerRadius = 12;
    self.contentView.layer.borderWidth  = 1;
    self.contentView.layer.borderColor  = SRFX_BORDER.CGColor;

    self.thumb = [[UIView alloc] init];
    self.thumb.layer.masksToBounds = YES;
    [self.contentView addSubview:self.thumb];

    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[(id)SRFX_PURPLE.CGColor, (id)SRFX_PINK.CGColor];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint   = CGPointMake(1, 1);
    [self.thumb.layer addSublayer:g];

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.textColor = SRFX_TEXT;
    self.titleLbl.font = [UIFont boldSystemFontOfSize:13];
    self.titleLbl.numberOfLines = 2;
    [self.contentView addSubview:self.titleLbl];

    self.gameLbl = [[UILabel alloc] init];
    self.gameLbl.textColor = SRFX_MUTED;
    self.gameLbl.font = [UIFont systemFontOfSize:11];
    [self.contentView addSubview:self.gameLbl];

    self.loadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.loadBtn setTitle:@"Load" forState:UIControlStateNormal];
    [self.loadBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.loadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    self.loadBtn.layer.cornerRadius = 8;
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)SRFX_PURPLE.CGColor, (id)SRFX_PINK.CGColor];
    bg.startPoint = CGPointMake(0, 0.5);
    bg.endPoint   = CGPointMake(1, 0.5);
    [self.loadBtn.layer insertSublayer:bg atIndex:0];
    [self.contentView addSubview:self.loadBtn];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    self.thumb.frame = CGRectMake(0, 0, 80, h);
    self.titleLbl.frame = CGRectMake(90, 8, w - 160, 32);
    self.gameLbl.frame = CGRectMake(90, 42, w - 160, 16);
    self.loadBtn.frame = CGRectMake(w - 68, h/2 - 14, 58, 28);
    for (CALayer *l in self.thumb.layer.sublayers)
        if ([l isKindOfClass:[CAGradientLayer class]]) l.frame = self.thumb.bounds;
    for (CALayer *l in self.loadBtn.layer.sublayers)
        if ([l isKindOfClass:[CAGradientLayer class]]) l.frame = self.loadBtn.bounds;
}

- (void)configureWithData:(NSDictionary *)d {
    self.titleLbl.text = d[@"title"] ?: @"Untitled";
    self.gameLbl.text  = d[@"game"]  ?: @"Universal";
}

@end

@interface SRFXMainViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) UIView        *panel;
@property (nonatomic, strong) UISearchBar   *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL panelVisible;
@end

@implementation SRFXMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    [self buildFloatButton];
    [self buildPanel];
    [self buildEditor];
    [self buildHub];
    [self buildConsole];
    self.panelVisible = NO;
    self.panel.hidden = YES;
    self.panel.alpha  = 0;
    self.scripts = [NSMutableArray array];
    self.consoleText = [NSMutableString string];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPrint:) name:@"SRFXPrint" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onError:) name:@"SRFXError" object:nil];
    [self loadTrending];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat sw = UIScreen.mainScreen.bounds.size.width;
    CGFloat sh = UIScreen.mainScreen.bounds.size.height;
    self.panel.frame = CGRectMake((sw - PANEL_W)/2, (sh - PANEL_H)/2, PANEL_W, PANEL_H);
}

- (void)buildFloatButton {
    self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatBtn.frame = CGRectMake(20, 100, 50, 50);
    self.floatBtn.layer.cornerRadius = 12;
    self.floatBtn.layer.shadowColor = SRFX_PURPLE.CGColor;
    self.floatBtn.layer.shadowOpacity = 0.8;
    self.floatBtn.layer.shadowRadius = 10;
    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors = @[(id)SRFX_PURPLE.CGColor, (id)SRFX_PINK.CGColor];
    g.frame = CGRectMake(0,0,50,50);
    g.cornerRadius = 12;
    [self.floatBtn.layer insertSublayer:g atIndex:0];
    [self.floatBtn setTitle:@"S" forState:UIControlStateNormal];
    [self.floatBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.floatBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloatBtn:)];
    [self.floatBtn addGestureRecognizer:pan];
    [self.view addSubview:self.floatBtn];
}

- (void)dragFloatBtn:(UIPanGestureRecognizer *)gr {
    CGPoint t = [gr translationInView:self.view];
    self.floatBtn.center = CGPointMake(self.floatBtn.center.x + t.x, self.floatBtn.center.y + t.y);
    [gr setTranslation:CGPointZero inView:self.view];
}

- (void)buildPanel {
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0,0,PANEL_W,PANEL_H)];
    self.panel.backgroundColor = SRFX_BG;
    self.panel.layer.cornerRadius = 16;
    self.panel.layer.borderWidth = 1.5;
    self.panel.layer.borderColor = SRFX_PURPLE.CGColor;
    [self.view addSubview:self.panel];
}

- (void)buildEditor {
    self.editor = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, PANEL_W-20, PANEL_H-80)];
    self.editor.backgroundColor = SRFX_SURFACE;
    self.editor.textColor = SRFX_TEXT;
    self.editor.font = [UIFont fontWithName:@"Menlo" size:13];
    self.editor.text = @"-- SERFIX\nprint('Hello')";
    [self.panel addSubview:self.editor];

    UIButton *execBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    execBtn.frame = CGRectMake(10, PANEL_H-60, 100, 40);
    [execBtn setTitle:@"Execute" forState:UIControlStateNormal];
    execBtn.backgroundColor = SRFX_PURPLE;
    execBtn.layer.cornerRadius = 8;
    [execBtn addTarget:self action:@selector(execute) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:execBtn];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(PANEL_W-50, 5, 40, 40);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:SRFX_MUTED forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:closeBtn];
}

- (void)buildHub {
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(10, 10, PANEL_W-20, 40)];
    self.searchBar.placeholder = @"Search ScriptBlox";
    self.searchBar.delegate = self;
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.hidden = YES;
    [self.panel addSubview:self.searchBar];

    self.scriptList = [[UITableView alloc] initWithFrame:CGRectMake(10, 60, PANEL_W-20, PANEL_H-120) style:UITableViewStylePlain];
    self.scriptList.backgroundColor = UIColor.clearColor;
    self.scriptList.delegate = self;
    self.scriptList.dataSource = self;
    self.scriptList.rowHeight = 80;
    self.scriptList.hidden = YES;
    [self.panel addSubview:self.scriptList];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(PANEL_W/2, PANEL_H/2);
    self.spinner.color = SRFX_PINK;
    self.spinner.hidden = YES;
    [self.panel addSubview:self.spinner];
}

- (void)buildConsole {
    self.consoleView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, PANEL_W-20, PANEL_H-60)];
    self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.05 alpha:1];
    self.consoleView.textColor = SRFX_GREEN;
    self.consoleView.font = [UIFont fontWithName:@"Menlo" size:12];
    self.consoleView.editable = NO;
    self.consoleView.hidden = YES;
    [self.panel addSubview:self.consoleView];
}

- (void)togglePanel {
    self.panelVisible = !self.panelVisible;
    self.panel.hidden = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.panel.alpha = self.panelVisible ? 1 : 0;
        self.panel.transform = self.panelVisible ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL f) {
        if (!self.panelVisible) self.panel.hidden = YES;
    }];
}

- (void)closePanel { self.panelVisible = YES; [self togglePanel]; }

- (void)loadTrending {
    [self.spinner startAnimating];
    self.spinner.hidden = NO;
    [SRFXScriptBlox fetchTrending:^(NSArray *s) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scripts removeAllObjects];
            [self.scripts addObjectsFromArray:s];
            [self.scriptList reloadData];
            [self.spinner stopAnimating];
            self.spinner.hidden = YES;
        });
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb {
    [sb resignFirstResponder];
    [self.spinner startAnimating];
    self.spinner.hidden = NO;
    [SRFXScriptBlox search:sb.text completion:^(NSArray *r) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scripts removeAllObjects];
            [self.scripts addObjectsFromArray:r];
            [self.scriptList reloadData];
            [self.spinner stopAnimating];
            self.spinner.hidden = YES;
        });
    }];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.scripts.count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    SRFXScriptCard *c = [t dequeueReusableCellWithIdentifier:@"c"];
    if (!c) c = [[SRFXScriptCard alloc] initWithStyle:0 reuseIdentifier:@"c"];
    [c configureWithData:self.scripts[ip.row]];
    c.loadBtn.tag = ip.row;
    [c.loadBtn addTarget:self action:@selector(loadCard:) forControlEvents:UIControlEventTouchUpInside];
    return c;
}

- (void)loadCard:(UIButton *)btn {
    NSInteger idx = btn.tag;
    if (idx >= self.scripts.count) return;
    NSString *slug = self.scripts[idx][@"slug"];
    [self.spinner startAnimating];
    self.spinner.hidden = NO;
    [SRFXScriptBlox fetchScript:slug completion:^(NSString *code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (code.length) {
                self.editor.text = code;
                [self showEditor];
            }
            [self.spinner stopAnimating];
            self.spinner.hidden = YES;
        });
    }];
}

- (void)showEditor {
    self.editor.hidden = NO;
    self.scriptList.hidden = YES;
    self.searchBar.hidden = YES;
    self.consoleView.hidden = YES;
}

- (void)execute {
    if (!self.editor.text.length) return;
    const char *s = self.editor.text.UTF8String;
    dispatch_async(dispatch_get_global_queue(0,0), ^{
        SRFXLuaExecute(s);
    });
    [self showConsole];
}

- (void)showConsole {
    self.editor.hidden = YES;
    self.scriptList.hidden = YES;
    self.searchBar.hidden = YES;
    self.consoleView.hidden = NO;
}

- (void)onPrint:(NSNotification *)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.consoleText appendFormat:@"%@\n", n.object];
        self.consoleView.text = self.consoleText;
    });
}

- (void)onError:(NSNotification *)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.consoleText appendFormat:@"[ERR] %@\n", n.object];
        self.consoleView.text = self.consoleText;
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
