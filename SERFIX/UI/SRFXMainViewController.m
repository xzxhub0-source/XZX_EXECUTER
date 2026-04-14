#import "SRFXMainViewController.h"
#import "SRFXScriptBlox.h"
void SRFXLuaExecute(const char *script);

#define SRFX_BG       [UIColor colorWithRed:0.04 green:0.04 blue:0.09 alpha:0.97]
#define SRFX_SURFACE  [UIColor colorWithRed:0.08 green:0.07 blue:0.14 alpha:1.0]
#define SRFX_SURFACE2 [UIColor colorWithRed:0.11 green:0.10 blue:0.18 alpha:1.0]
#define SRFX_PURPLE   [UIColor colorWithRed:0.55 green:0.18 blue:0.79 alpha:1.0]
#define SRFX_PINK     [UIColor colorWithRed:1.00 green:0.12 blue:0.56 alpha:1.0]
#define SRFX_BORDER   [UIColor colorWithRed:0.25 green:0.14 blue:0.42 alpha:1.0]
#define SRFX_TEXT     [UIColor colorWithRed:0.92 green:0.88 blue:1.00 alpha:1.0]
#define SRFX_MUTED    [UIColor colorWithRed:0.55 green:0.50 blue:0.68 alpha:1.0]

#define PANEL_W  MIN(UIScreen.mainScreen.bounds.size.width  - 24, 640.0)
#define PANEL_H  MIN(UIScreen.mainScreen.bounds.size.height - 80, 480.0)
#define SIDEBAR_W 52.0

@interface SRFXScriptCell : UITableViewCell
@property (nonatomic, strong) UIView   *thumb;
@property (nonatomic, strong) UILabel  *titleLbl;
@property (nonatomic, strong) UILabel  *gameLbl;
@property (nonatomic, strong) UILabel  *viewsLbl;
@property (nonatomic, strong) UIButton *runBtn;
- (void)configureWithData:(NSDictionary *)d gradientIndex:(NSInteger)idx;
@end

@implementation SRFXScriptCell

- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    self = [super initWithStyle:s reuseIdentifier:r];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.selectionStyle  = UITableViewCellSelectionStyleNone;
    self.contentView.backgroundColor = SRFX_SURFACE2;
    self.contentView.layer.cornerRadius = 12;
    self.contentView.layer.borderWidth  = 1;
    self.contentView.layer.borderColor  = SRFX_BORDER.CGColor;
    self.contentView.layer.masksToBounds = YES;
    
    self.thumb = [[UIView alloc] init];
    self.thumb.layer.masksToBounds = YES;
    [self.contentView addSubview:self.thumb];
    
    CAGradientLayer *g = [CAGradientLayer layer];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint   = CGPointMake(1, 1);
    [self.thumb.layer addSublayer:g];
    
    UILabel *iconLbl = [[UILabel alloc] init];
    iconLbl.text          = @"</>";
    iconLbl.textColor     = [UIColor colorWithWhite:1 alpha:0.3];
    iconLbl.font          = [UIFont boldSystemFontOfSize:20];
    iconLbl.textAlignment = NSTextAlignmentCenter;
    [self.thumb addSubview:iconLbl];
    
    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.textColor     = SRFX_TEXT;
    self.titleLbl.font          = [UIFont boldSystemFontOfSize:13];
    self.titleLbl.numberOfLines = 2;
    [self.contentView addSubview:self.titleLbl];
    
    self.gameLbl = [[UILabel alloc] init];
    self.gameLbl.textColor = SRFX_MUTED;
    self.gameLbl.font      = [UIFont systemFontOfSize:11];
    [self.contentView addSubview:self.gameLbl];
    
    self.viewsLbl = [[UILabel alloc] init];
    self.viewsLbl.textColor = SRFX_MUTED;
    self.viewsLbl.font      = [UIFont systemFontOfSize:10];
    [self.contentView addSubview:self.viewsLbl];
    
    self.runBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.runBtn setTitle:@"Load" forState:UIControlStateNormal];
    [self.runBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.runBtn.titleLabel.font    = [UIFont boldSystemFontOfSize:12];
    self.runBtn.layer.cornerRadius = 8;
    self.runBtn.layer.masksToBounds = YES;
    [self.contentView addSubview:self.runBtn];
    
    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.startPoint = CGPointMake(0, 0.5);
    bg.endPoint   = CGPointMake(1, 0.5);
    [self.runBtn.layer insertSublayer:bg atIndex:0];
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.contentView.bounds.size.height;
    CGFloat w = self.contentView.bounds.size.width;
    
    self.thumb.frame = CGRectMake(0, 0, 90, h);
    for (UIView *sub in self.thumb.subviews) sub.frame = self.thumb.bounds;
    for (CALayer *l in self.thumb.layer.sublayers) l.frame = self.thumb.bounds;
    
    self.titleLbl.frame = CGRectMake(100, 8, w - 170, 32);
    self.gameLbl.frame  = CGRectMake(100, 42, w - 170, 16);
    self.viewsLbl.frame = CGRectMake(100, 56, 80, 14);
    self.runBtn.frame   = CGRectMake(w - 68, h/2 - 14, 58, 28);
    
    for (CALayer *l in self.runBtn.layer.sublayers)
        if ([l isKindOfClass:[CAGradientLayer class]])
            l.frame = self.runBtn.bounds;
}

- (void)configureWithData:(NSDictionary *)d gradientIndex:(NSInteger)idx {
    self.titleLbl.text = d[@"title"] ?: @"Untitled";
    self.gameLbl.text  = d[@"game"]  ?: @"Universal";
    self.viewsLbl.text = d[@"views"] ? [NSString stringWithFormat:@"👁 %@", d[@"views"]] : @"";
    
    static NSArray *palettes = nil;
    if (!palettes) palettes = @[
        @[@"#8B2FC9",@"#FF1F8F"],
        @[@"#4B2FC9",@"#FF1F4F"],
        @[@"#C92F8B",@"#FF8F1F"],
        @[@"#2F4BC9",@"#8F1FFF"],
        @[@"#C92F4B",@"#FF2FBF"],
    ];
    NSArray *pair = palettes[idx % palettes.count];
    
    unsigned int rgb1 = 0, rgb2 = 0;
    [[NSScanner scannerWithString:[pair[0] substringFromIndex:1]] scanHexInt:&rgb1];
    [[NSScanner scannerWithString:[pair[1] substringFromIndex:1]] scanHexInt:&rgb2];
    UIColor *c1 = [UIColor colorWithRed:((rgb1>>16)&0xFF)/255.0 green:((rgb1>>8)&0xFF)/255.0 blue:(rgb1&0xFF)/255.0 alpha:1];
    UIColor *c2 = [UIColor colorWithRed:((rgb2>>16)&0xFF)/255.0 green:((rgb2>>8)&0xFF)/255.0 blue:(rgb2&0xFF)/255.0 alpha:1];
    
    for (CALayer *l in self.thumb.layer.sublayers) {
        if ([l isKindOfClass:[CAGradientLayer class]]) {
            ((CAGradientLayer *)l).colors = @[(id)c1.CGColor, (id)c2.CGColor];
            break;
        }
    }
    for (CALayer *l in self.runBtn.layer.sublayers) {
        if ([l isKindOfClass:[CAGradientLayer class]]) {
            ((CAGradientLayer *)l).colors = @[(id)SRFX_PURPLE.CGColor, (id)SRFX_PINK.CGColor];
            break;
        }
    }
}

@end

#pragma mark - Sidebar Button

@interface SRFXSidebarButton : UIButton
@property (nonatomic, assign) BOOL srfxSelected;
@end
@implementation SRFXSidebarButton
- (void)setSrfxSelected:(BOOL)s {
    _srfxSelected = s;
    UIColor *c = s ? [UIColor whiteColor] : [UIColor colorWithWhite:1 alpha:0.35];
    [self setTitleColor:c forState:UIControlStateNormal];
    if (s) {
        self.backgroundColor = [SRFX_PURPLE colorWithAlphaComponent:0.28];
        self.layer.borderColor = SRFX_PURPLE.CGColor;
        self.layer.borderWidth = 1;
    } else {
        self.backgroundColor = UIColor.clearColor;
        self.layer.borderWidth = 0;
    }
}
@end

#pragma mark - Main View Controller

@interface SRFXMainViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) UIView        *panel;
@property (nonatomic, strong) UIView        *sidebar;
@property (nonatomic, strong) UIView        *contentArea;
@property (nonatomic, strong) NSArray<SRFXSidebarButton*> *sideBtns;
@property (nonatomic, strong) UIView        *header;
@property (nonatomic, strong) UISearchBar   *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UITextView    *lineNumbers;
@property (nonatomic, assign) BOOL           panelVisible;
@end

@implementation SRFXMainViewController

- (CAGradientLayer *)purplePinkGradientForFrame:(CGRect)f {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.colors     = @[(id)SRFX_PURPLE.CGColor, (id)SRFX_PINK.CGColor];
    g.startPoint = CGPointMake(0, 0.5);
    g.endPoint   = CGPointMake(1, 0.5);
    g.frame      = f;
    return g;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    [self buildFloatButton];
    [self buildPanel];
    [self buildSidebar];
    [self buildHeader];
    [self buildEditorTab];
    [self buildHubTab];
    [self buildConsoleTab];
    self.panelVisible = NO;
    self.panel.hidden = YES;
    self.panel.alpha  = 0;
    self.selectedTab  = 0;
    [self switchToTab:0];
    self.scripts     = [NSMutableArray array];
    self.consoleText = [NSMutableString string];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPrint:) name:@"SRFXPrint" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onError:) name:@"SRFXError" object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat sw = UIScreen.mainScreen.bounds.size.width;
    CGFloat sh = UIScreen.mainScreen.bounds.size.height;
    CGFloat pw = PANEL_W, ph = PANEL_H;
    self.panel.frame = CGRectMake((sw - pw) / 2, (sh - ph) / 2, pw, ph);
    [self relayoutContentArea];
}

- (void)buildFloatButton {
    self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatBtn.frame = CGRectMake(20, 100, 50, 50);
    self.floatBtn.layer.cornerRadius = 12;
    self.floatBtn.layer.masksToBounds = YES;
    self.floatBtn.layer.shadowColor   = SRFX_PINK.CGColor;
    self.floatBtn.layer.shadowOpacity = 0.7;
    self.floatBtn.layer.shadowRadius  = 12;
    self.floatBtn.layer.shadowOffset  = CGSizeZero;
    CAGradientLayer *g = [self purplePinkGradientForFrame:CGRectMake(0,0,50,50)];
    [self.floatBtn.layer insertSublayer:g atIndex:0];
    [self.floatBtn setTitle:@"S" forState:UIControlStateNormal];
    [self.floatBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
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
    CGFloat pw = PANEL_W, ph = PANEL_H;
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, ph)];
    self.panel.backgroundColor    = SRFX_BG;
    self.panel.layer.cornerRadius = 16;
    self.panel.layer.masksToBounds = YES;
    self.panel.layer.borderWidth  = 1;
    self.panel.layer.borderColor  = [SRFX_PURPLE colorWithAlphaComponent:0.6].CGColor;
    self.panel.layer.shadowColor   = SRFX_PURPLE.CGColor;
    self.panel.layer.shadowOpacity = 0.3;
    self.panel.layer.shadowRadius  = 24;
    self.panel.layer.shadowOffset  = CGSizeZero;
    [self.view addSubview:self.panel];
}

- (void)buildSidebar {
    CGFloat ph = PANEL_H;
    self.sidebar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SIDEBAR_W, ph)];
    self.sidebar.backgroundColor = SRFX_SURFACE;
    [self.panel addSubview:self.sidebar];
    
    UIView *border = [[UIView alloc] initWithFrame:CGRectMake(SIDEBAR_W-1, 0, 1, ph)];
    border.backgroundColor = SRFX_BORDER;
    [self.sidebar addSubview:border];
    
    UILabel *logo = [[UILabel alloc] initWithFrame:CGRectMake(0, 14, SIDEBAR_W, 26)];
    logo.text = @"S";
    logo.textColor = SRFX_PINK;
    logo.font = [UIFont boldSystemFontOfSize:22];
    logo.textAlignment = NSTextAlignmentCenter;
    [self.sidebar addSubview:logo];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(8, 46, SIDEBAR_W-16, 1)];
    sep.backgroundColor = SRFX_BORDER;
    [self.sidebar addSubview:sep];
    
    NSArray *icons = @[@"< >", @"◎", @"⌨", @"≡"];
    NSMutableArray *btns = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)icons.count; i++) {
        SRFXSidebarButton *btn = [SRFXSidebarButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(6, 56 + i*52, SIDEBAR_W-12, 42);
        btn.layer.cornerRadius = 10;
        btn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        [btn setTitle:icons[i] forState:UIControlStateNormal];
        btn.tag = i;
        [btn addTarget:self action:@selector(sidebarTap:) forControlEvents:UIControlEventTouchUpInside];
        btn.srfxSelected = (i == 0);
        [self.sidebar addSubview:btn];
        [btns addObject:btn];
    }
    self.sideBtns = btns;
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(6, ph - 52, SIDEBAR_W-12, 38);
    closeBtn.layer.cornerRadius = 10;
    closeBtn.backgroundColor = [UIColor colorWithRed:1 green:0.1 blue:0.1 alpha:0.18];
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithRed:1 green:0.4 blue:0.4 alpha:1] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.sidebar addSubview:closeBtn];
}

- (void)buildHeader {
    CGFloat pw = PANEL_W;
    self.header = [[UIView alloc] initWithFrame:CGRectMake(SIDEBAR_W, 0, pw - SIDEBAR_W, 44)];
    self.header.backgroundColor = SRFX_SURFACE;
    [self.panel addSubview:self.header];
    
    CAGradientLayer *line = [self purplePinkGradientForFrame:CGRectMake(0, 43, pw - SIDEBAR_W, 1)];
    [self.header.layer addSublayer:line];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 150, 44)];
    title.text = @"SERFIX";
    title.textColor = SRFX_TEXT;
    title.font = [UIFont boldSystemFontOfSize:16];
    [self.header addSubview:title];
    
    UILabel *version = [[UILabel alloc] initWithFrame:CGRectMake(80, 6, 60, 14)];
    version.text = @"v2.5";
    version.font = [UIFont systemFontOfSize:10];
    version.textColor = SRFX_MUTED;
    [self.header addSubview:version];
    
    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPanel:)];
    [self.header addGestureRecognizer:drag];
    
    self.contentArea = [[UIView alloc] init];
    self.contentArea.backgroundColor = SRFX_BG;
    self.contentArea.clipsToBounds = YES;
    [self.panel addSubview:self.contentArea];
}

- (void)buildEditorTab {
    self.lineNumbers = [[UITextView alloc] init];
    self.lineNumbers.backgroundColor   = SRFX_SURFACE;
    self.lineNumbers.textColor         = SRFX_MUTED;
    self.lineNumbers.font              = [UIFont fontWithName:@"Menlo" size:13];
    self.lineNumbers.editable          = NO;
    self.lineNumbers.scrollEnabled     = NO;
    self.lineNumbers.textAlignment     = NSTextAlignmentRight;
    self.lineNumbers.textContainerInset = UIEdgeInsetsMake(10, 4, 10, 6);
    self.lineNumbers.text = @"1\n2";
    self.lineNumbers.tag  = 10;
    [self.contentArea addSubview:self.lineNumbers];
    
    self.editor = [[UITextView alloc] init];
    self.editor.backgroundColor        = SRFX_BG;
    self.editor.textColor              = SRFX_TEXT;
    self.editor.font                   = [UIFont fontWithName:@"Menlo" size:13];
    self.editor.text                   = @"-- SERFIX Executor v2.5\nprint('Hello from SERFIX!')";
    self.editor.autocorrectionType     = UITextAutocorrectionTypeNo;
    self.editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.editor.textContainerInset     = UIEdgeInsetsMake(10, 8, 10, 8);
    self.editor.tag  = 11;
    [self.contentArea addSubview:self.editor];
    
    UIView *toolbar = [[UIView alloc] init];
    toolbar.backgroundColor = SRFX_SURFACE;
    toolbar.tag = 12;
    [self.contentArea addSubview:toolbar];
    
    UIView *tBorder = [[UIView alloc] init];
    tBorder.backgroundColor = SRFX_BORDER;
    [toolbar addSubview:tBorder];
    
    UIButton *execBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    execBtn.tag = 20;
    execBtn.layer.cornerRadius = 8;
    execBtn.layer.masksToBounds = YES;
    [execBtn setTitle:@"▶  Execute" forState:UIControlStateNormal];
    [execBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    execBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    CAGradientLayer *eg = [self purplePinkGradientForFrame:CGRectMake(0,0,110,36)];
    [execBtn.layer insertSublayer:eg atIndex:0];
    [execBtn addTarget:self action:@selector(execute) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:execBtn];
    
    UIButton *clrBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    clrBtn.tag = 21;
    clrBtn.layer.cornerRadius = 8;
    clrBtn.backgroundColor = [UIColor colorWithRed:1 green:0.1 blue:0.1 alpha:0.2];
    clrBtn.layer.borderColor = [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:0.4].CGColor;
    clrBtn.layer.borderWidth = 1;
    [clrBtn setTitle:@"Clear" forState:UIControlStateNormal];
    [clrBtn setTitleColor:[UIColor colorWithRed:1 green:0.5 blue:0.5 alpha:1] forState:UIControlStateNormal];
    clrBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [clrBtn addTarget:self action:@selector(clearEditor) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:clrBtn];
    
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    saveBtn.tag = 22;
    saveBtn.layer.cornerRadius = 8;
    saveBtn.backgroundColor = SRFX_SURFACE2;
    saveBtn.layer.borderColor = SRFX_BORDER.CGColor;
    saveBtn.layer.borderWidth = 1;
    [saveBtn setTitle:@"Save" forState:UIControlStateNormal];
    [saveBtn setTitleColor:SRFX_MUTED forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [saveBtn addTarget:self action:@selector(saveScript) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:saveBtn];
}

- (void)buildHubTab {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.tag = 30;
    self.searchBar.placeholder = @"Search scripts...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.delegate = self;
    self.searchBar.tintColor = SRFX_PINK;
    self.searchBar.barTintColor = SRFX_SURFACE;
    self.searchBar.searchTextField.backgroundColor = SRFX_SURFACE2;
    self.searchBar.searchTextField.textColor = SRFX_TEXT;
    self.searchBar.hidden = YES;
    [self.contentArea addSubview:self.searchBar];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = SRFX_PINK;
    self.spinner.hidesWhenStopped = YES;
    self.spinner.tag = 31;
    [self.contentArea addSubview:self.spinner];
    
    UILabel *trending = [[UILabel alloc] init];
    trending.text = @"TRENDING SCRIPTS";
    trending.font = [UIFont boldSystemFontOfSize:10];
    trending.textColor = SRFX_MUTED;
    trending.tag = 32;
    trending.hidden = YES;
    [self.contentArea addSubview:trending];
    
    self.scriptList = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.scriptList.tag = 33;
    self.scriptList.backgroundColor = UIColor.clearColor;
    self.scriptList.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.scriptList.delegate = self;
    self.scriptList.dataSource = self;
    self.scriptList.rowHeight = 80;
    self.scriptList.contentInset = UIEdgeInsetsMake(4, 0, 4, 0);
    self.scriptList.hidden = YES;
    [self.contentArea addSubview:self.scriptList];
    
    [self loadTrending];
}

- (void)buildConsoleTab {
    self.consoleView = [[UITextView alloc] init];
    self.consoleView.tag = 40;
    self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.06 alpha:1];
    self.consoleView.textColor = [UIColor colorWithRed:0.5 green:1.0 blue:0.5 alpha:1];
    self.consoleView.font = [UIFont fontWithName:@"Menlo" size:12];
    self.consoleView.editable = NO;
    self.consoleView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.consoleView.hidden = YES;
    [self.contentArea addSubview:self.consoleView];
    
    UIButton *clrConsole = [UIButton buttonWithType:UIButtonTypeCustom];
    clrConsole.tag = 41;
    clrConsole.layer.cornerRadius = 6;
    clrConsole.backgroundColor = SRFX_SURFACE2;
    clrConsole.layer.borderColor = SRFX_BORDER.CGColor;
    clrConsole.layer.borderWidth = 1;
    [clrConsole setTitle:@"Clear Console" forState:UIControlStateNormal];
    [clrConsole setTitleColor:SRFX_MUTED forState:UIControlStateNormal];
    clrConsole.titleLabel.font = [UIFont systemFontOfSize:12];
    [clrConsole addTarget:self action:@selector(clearConsole) forControlEvents:UIControlEventTouchUpInside];
    clrConsole.hidden = YES;
    [self.contentArea addSubview:clrConsole];
}

- (void)relayoutContentArea {
    CGFloat pw = self.panel.bounds.size.width;
    CGFloat ph = self.panel.bounds.size.height;
    CGFloat cw = pw - SIDEBAR_W;
    CGFloat ch = ph - 44;
    
    self.header.frame      = CGRectMake(SIDEBAR_W, 0, cw, 44);
    self.sidebar.frame     = CGRectMake(0, 0, SIDEBAR_W, ph);
    self.contentArea.frame = CGRectMake(SIDEBAR_W, 44, cw, ch);
    
    UIView *ln = [self.contentArea viewWithTag:10];
    UIView *ed = [self.contentArea viewWithTag:11];
    UIView *tb = [self.contentArea viewWithTag:12];
    CGFloat tbH = 52;
    ln.frame = CGRectMake(0, 0, 30, ch - tbH);
    ed.frame = CGRectMake(30, 0, cw - 30, ch - tbH);
    tb.frame = CGRectMake(0, ch - tbH, cw, tbH);
    for (UIView *sub in tb.subviews) if (sub.tag != 20 && sub.tag != 21 && sub.tag != 22) sub.frame = tb.bounds;
    
    [tb viewWithTag:20].frame = CGRectMake(10, 8, 110, 36);
    [tb viewWithTag:21].frame = CGRectMake(130, 8, 80, 36);
    [tb viewWithTag:22].frame = CGRectMake(220, 8, 70, 36);
    
    for (UIView *b in @[[tb viewWithTag:20], [tb viewWithTag:21], [tb viewWithTag:22]])
        for (CALayer *l in b.layer.sublayers)
            if ([l isKindOfClass:[CAGradientLayer class]])
                l.frame = b.bounds;
    
    [self.contentArea viewWithTag:30].frame = CGRectMake(0, 0, cw, 44);
    self.spinner.center = CGPointMake(cw/2, ch/2);
    [self.contentArea viewWithTag:32].frame = CGRectMake(12, 50, cw - 24, 14);
    [self.contentArea viewWithTag:33].frame = CGRectMake(0, 66, cw, ch - 66);
    [self.contentArea viewWithTag:40].frame = CGRectMake(0, 0, cw, ch - 42);
    [self.contentArea viewWithTag:41].frame = CGRectMake(cw/2 - 60, ch - 36, 120, 28);
}

- (void)sidebarTap:(UIButton *)sender { [self switchToTab:sender.tag]; }

- (void)switchToTab:(NSInteger)idx {
    self.selectedTab = idx;
    for (SRFXSidebarButton *b in self.sideBtns) b.srfxSelected = (b.tag == idx);
    for (NSInteger i = 10; i <= 12; i++) [self.contentArea viewWithTag:i].hidden = (idx != 0);
    for (NSInteger i = 30; i <= 33; i++) [self.contentArea viewWithTag:i].hidden = (idx != 1);
    for (NSInteger i = 40; i <= 41; i++) [self.contentArea viewWithTag:i].hidden = (idx != 2);
}

- (void)togglePanel {
    self.panelVisible = !self.panelVisible;
    self.panel.hidden = NO;
    [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.4 options:0 animations:^{
        self.panel.alpha = self.panelVisible ? 1 : 0;
        self.panel.transform = self.panelVisible ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL _) { if (!self.panelVisible) self.panel.hidden = YES; }];
}

- (void)closePanel { self.panelVisible = YES; [self togglePanel]; }

- (void)dragPanel:(UIPanGestureRecognizer *)gr {
    CGPoint t = [gr translationInView:self.view];
    self.panel.center = CGPointMake(self.panel.center.x + t.x, self.panel.center.y + t.y);
    [gr setTranslation:CGPointZero inView:self.view];
}

- (void)loadTrending {
    [self.spinner startAnimating];
    [SRFXScriptBlox fetchTrending:^(NSArray *s) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scripts removeAllObjects];
            [self.scripts addObjectsFromArray:s];
            [self.scriptList reloadData];
            [self.spinner stopAnimating];
        });
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb {
    [sb resignFirstResponder];
    if (sb.text.length == 0) { [self loadTrending]; return; }
    [self.spinner startAnimating];
    [SRFXScriptBlox search:sb.text completion:^(NSArray *r) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scripts removeAllObjects];
            [self.scripts addObjectsFromArray:r];
            [self.scriptList reloadData];
            [self.spinner stopAnimating];
        });
    }];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.scripts.count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    SRFXScriptCell *c = [t dequeueReusableCellWithIdentifier:@"sc"];
    if (!c) c = [[SRFXScriptCell alloc] initWithStyle:0 reuseIdentifier:@"sc"];
    [c configureWithData:self.scripts[ip.row] gradientIndex:ip.row];
    c.runBtn.tag = ip.row;
    [c.runBtn addTarget:self action:@selector(loadScriptRow:) forControlEvents:UIControlEventTouchUpInside];
    return c;
}

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip { return 88; }

- (void)loadScriptRow:(UIButton *)sender {
    if (sender.tag < (NSInteger)self.scripts.count)
        [self fetchAndLoadSlug:self.scripts[sender.tag][@"slug"]];
}

- (void)fetchAndLoadSlug:(NSString *)slug {
    if (!slug.length) return;
    [self.spinner startAnimating];
    [SRFXScriptBlox fetchScript:slug completion:^(NSString *code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (code.length) { self.editor.text = code; [self switchToTab:0]; [self updateLineNumbers]; }
            [self.spinner stopAnimating];
        });
    }];
}

- (void)execute {
    if (!self.editor.text.length) return;
    SRFXLuaExecute(self.editor.text.UTF8String);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (self.consoleText.length) [self switchToTab:2];
    });
}

- (void)clearEditor { self.editor.text = @""; [self updateLineNumbers]; }

- (void)saveScript {
    if (!self.editor.text.length) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableArray *saved = [([ud arrayForKey:@"SRFXSaved"] ?: @[]) mutableCopy];
    [saved insertObject:self.editor.text atIndex:0];
    if (saved.count > 20) [saved removeLastObject];
    [ud setObject:saved forKey:@"SRFXSaved"];
}

- (void)updateLineNumbers {
    NSUInteger lines = [[self.editor.text componentsSeparatedByString:@"\n"] count];
    NSMutableString *nums = [NSMutableString string];
    for (NSUInteger i = 1; i <= MAX(lines, 2); i++) [nums appendFormat:@"%lu\n", (unsigned long)i];
    self.lineNumbers.text = nums;
}

- (void)clearConsole { self.consoleText = [NSMutableString string]; self.consoleView.text = @""; }

- (void)onPrint:(NSNotification *)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.consoleText appendFormat:@"[OUT] %@\n", n.object];
        self.consoleView.text = self.consoleText;
        [self.consoleView scrollRangeToVisible:NSMakeRange(self.consoleText.length, 0)];
    });
}

- (void)onError:(NSNotification *)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.consoleText appendFormat:@"[ERR] %@\n", n.object];
        self.consoleView.text = self.consoleText;
    });
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end
