#import "SRFXMainViewController.h"
#import "SRFXScriptBlox.h"
void SRFXLuaExecute(const char *script);

#define SRFX_BG        [UIColor colorWithRed:0.04 green:0.04 blue:0.09 alpha:0.97]
#define SRFX_SURFACE   [UIColor colorWithRed:0.07 green:0.07 blue:0.13 alpha:1.0]
#define SRFX_SURFACE2  [UIColor colorWithRed:0.11 green:0.10 blue:0.18 alpha:1.0]
#define SRFX_PURPLE    [UIColor colorWithRed:0.53 green:0.17 blue:0.77 alpha:1.0]
#define SRFX_PINK      [UIColor colorWithRed:1.00 green:0.12 blue:0.56 alpha:1.0]
#define SRFX_GREEN     [UIColor colorWithRed:0.18 green:0.78 blue:0.45 alpha:1.0]
#define SRFX_BORDER    [UIColor colorWithRed:0.24 green:0.14 blue:0.40 alpha:1.0]
#define SRFX_TEXT      [UIColor colorWithRed:0.92 green:0.88 blue:1.00 alpha:1.0]
#define SRFX_MUTED     [UIColor colorWithRed:0.55 green:0.50 blue:0.68 alpha:1.0]

#define PANEL_W   MIN(UIScreen.mainScreen.bounds.size.width  - 20, 660.0)
#define PANEL_H   MIN(UIScreen.mainScreen.bounds.size.height - 70, 490.0)
#define LEFT_W    190.0
#define DOCK_W    52.0

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - Script Card Cell
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@interface SRFXScriptCard : UITableViewCell
@property (nonatomic, strong) UIView      *thumb;
@property (nonatomic, strong) UILabel     *iconLabel;
@property (nonatomic, strong) UIImageView *thumbImage;
@property (nonatomic, strong) UILabel     *titleLbl;
@property (nonatomic, strong) UILabel     *gameLbl;
@property (nonatomic, strong) UILabel     *viewsLbl;
@property (nonatomic, strong) UILabel     *patchedBadge;
@property (nonatomic, strong) UIButton    *loadBtn;
@end

@implementation SRFXScriptCard

- (instancetype)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    self = [super initWithStyle:s reuseIdentifier:r];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.selectionStyle  = UITableViewCellSelectionStyleNone;

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = SRFX_SURFACE2;
    card.layer.cornerRadius = 12;
    card.layer.borderWidth  = 1;
    card.layer.borderColor  = SRFX_BORDER.CGColor;
    card.layer.masksToBounds = YES;
    card.tag = 99;
    [self.contentView addSubview:card];

    self.thumb = [[UIView alloc] init];
    self.thumb.layer.masksToBounds = YES;
    [card addSubview:self.thumb];

    CAGradientLayer *g = [CAGradientLayer layer];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint   = CGPointMake(1, 1);
    [self.thumb.layer addSublayer:g];

    self.thumbImage = [[UIImageView alloc] init];
    self.thumbImage.contentMode = UIViewContentModeScaleAspectFill;
    self.thumbImage.alpha = 0.75;
    [self.thumb addSubview:self.thumbImage];

    self.iconLabel = [[UILabel alloc] init];
    self.iconLabel.text          = @"</>";
    self.iconLabel.textColor     = [UIColor colorWithWhite:1 alpha:0.45];
    self.iconLabel.font          = [UIFont boldSystemFontOfSize:22];
    self.iconLabel.textAlignment = NSTextAlignmentCenter;
    [self.thumb addSubview:self.iconLabel];

    self.titleLbl = [[UILabel alloc] init];
    self.titleLbl.textColor     = SRFX_TEXT;
    self.titleLbl.font          = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.titleLbl.numberOfLines = 2;
    [card addSubview:self.titleLbl];

    self.gameLbl = [[UILabel alloc] init];
    self.gameLbl.textColor = SRFX_MUTED;
    self.gameLbl.font      = [UIFont systemFontOfSize:11];
    [card addSubview:self.gameLbl];

    self.viewsLbl = [[UILabel alloc] init];
    self.viewsLbl.textColor = SRFX_MUTED;
    self.viewsLbl.font      = [UIFont systemFontOfSize:10];
    [card addSubview:self.viewsLbl];

    self.patchedBadge = [[UILabel alloc] init];
    self.patchedBadge.text            = @"PATCHED";
    self.patchedBadge.textColor       = [UIColor colorWithRed:1 green:0.4 blue:0.4 alpha:1];
    self.patchedBadge.font            = [UIFont systemFontOfSize:9 weight:UIFontWeightBold];
    self.patchedBadge.backgroundColor = [UIColor colorWithRed:1 green:0.1 blue:0.1 alpha:0.2];
    self.patchedBadge.layer.cornerRadius  = 4;
    self.patchedBadge.layer.masksToBounds = YES;
    self.patchedBadge.textAlignment   = NSTextAlignmentCenter;
    self.patchedBadge.hidden          = YES;
    [card addSubview:self.patchedBadge];

    self.loadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.loadBtn setTitle:@"Load" forState:UIControlStateNormal];
    [self.loadBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.loadBtn.titleLabel.font    = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.loadBtn.layer.cornerRadius = 8;
    self.loadBtn.layer.masksToBounds = YES;
    CAGradientLayer *btnG = [CAGradientLayer layer];
    btnG.colors     = @[(id)SRFX_PURPLE.CGColor, (id)SRFX_PINK.CGColor];
    btnG.startPoint = CGPointMake(0, 0.5);
    btnG.endPoint   = CGPointMake(1, 0.5);
    [self.loadBtn.layer insertSublayer:btnG atIndex:0];
    [card addSubview:self.loadBtn];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat cw = self.contentView.bounds.size.width  - 16;
    CGFloat ch = self.contentView.bounds.size.height - 10;
    UIView *card = [self.contentView viewWithTag:99];
    card.frame = CGRectMake(8, 5, cw, ch);

    CGFloat thumbW = 96;
    self.thumb.frame      = CGRectMake(0, 0, thumbW, ch);
    self.thumbImage.frame = self.thumb.bounds;
    self.iconLabel.frame  = self.thumb.bounds;
    for (CALayer *l in self.thumb.layer.sublayers)
        if ([l isKindOfClass:[CAGradientLayer class]])
            l.frame = self.thumb.bounds;

    CGFloat tx  = thumbW + 10;
    CGFloat trw = cw - tx - 70;
    self.titleLbl.frame     = CGRectMake(tx, 8,  trw, 34);
    self.gameLbl.frame      = CGRectMake(tx, 44, trw, 16);
    self.viewsLbl.frame     = CGRectMake(tx, 60, 80,  14);
    self.patchedBadge.frame = CGRectMake(tx + 84, 60, 60, 14);
    self.loadBtn.frame      = CGRectMake(cw - 62, ch/2 - 15, 54, 30);
    for (CALayer *l in self.loadBtn.layer.sublayers)
        if ([l isKindOfClass:[CAGradientLayer class]])
            l.frame = self.loadBtn.bounds;
}

- (void)configureWithData:(NSDictionary *)d index:(NSInteger)idx {
    self.titleLbl.text = d[@"title"] ?: @"Untitled";
    self.gameLbl.text  = d[@"game"]  ?: @"Universal";
    id views = d[@"views"];
    if (views && ![views isEqual:@"0"] && ![views isEqual:@0]) {
        NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
        fmt.numberStyle = NSNumberFormatterDecimalStyle;
        self.viewsLbl.text = [NSString stringWithFormat:@"👁  %@",
            [fmt stringFromNumber:@([views integerValue])]];
    } else {
        self.viewsLbl.text = @"";
    }
    self.patchedBadge.hidden = ![d[@"isPatched"] boolValue];

    static NSArray *palettes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        palettes = @[
            @[@(0x7B22D1), @(0xFF1F6E)],
            @[@(0x3B22D1), @(0xFF1F3E)],
            @[@(0xC1227B), @(0xFF7F1F)],
            @[@(0x224BC1), @(0x8F1FFF)],
            @[@(0xC12244), @(0xFF2FAF)],
            @[@(0x22A1C1), @(0x7F1FFF)],
        ];
    });
    NSArray *pair = palettes[idx % palettes.count];
    unsigned int rgb1 = [pair[0] unsignedIntValue];
    unsigned int rgb2 = [pair[1] unsignedIntValue];
    UIColor *c1 = [UIColor colorWithRed:((rgb1>>16)&0xFF)/255.0
                                  green:((rgb1>>8)&0xFF)/255.0
                                   blue:(rgb1&0xFF)/255.0 alpha:1];
    UIColor *c2 = [UIColor colorWithRed:((rgb2>>16)&0xFF)/255.0
                                  green:((rgb2>>8)&0xFF)/255.0
                                   blue:(rgb2&0xFF)/255.0 alpha:1];
    for (CALayer *l in self.thumb.layer.sublayers)
        if ([l isKindOfClass:[CAGradientLayer class]])
            ((CAGradientLayer *)l).colors = @[(id)c1.CGColor, (id)c2.CGColor];

    self.thumbImage.image = nil;
    self.iconLabel.hidden = NO;
    NSString *imgUrl = d[@"imageUrl"];
    if (imgUrl.length) {
        NSURL *url = [NSURL URLWithString:imgUrl];
        if (url) {
            [[[NSURLSession sharedSession] dataTaskWithURL:url
                completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
                if (data && !e) {
                    UIImage *img = [UIImage imageWithData:data];
                    if (img) dispatch_async(dispatch_get_main_queue(), ^{
                        self.thumbImage.image = img;
                        self.iconLabel.hidden = YES;
                    });
                }
            }] resume];
        }
    }
}

@end

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - Dock Button
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@interface SRFXDockButton : UIButton
@property (nonatomic, assign) BOOL dockSelected;
@end
@implementation SRFXDockButton
- (void)setDockSelected:(BOOL)s {
    _dockSelected = s;
    if (s) {
        self.backgroundColor  = [UIColor colorWithRed:0.53 green:0.17 blue:0.77 alpha:0.28];
        self.layer.borderColor = SRFX_PURPLE.CGColor;
        self.layer.borderWidth = 1;
        [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    } else {
        self.backgroundColor   = UIColor.clearColor;
        self.layer.borderWidth = 0;
        [self setTitleColor:[UIColor colorWithWhite:1 alpha:0.38] forState:UIControlStateNormal];
    }
}
@end

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#pragma mark - Main View Controller
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@interface SRFXMainViewController ()
    <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) UIView  *panel;
@property (nonatomic, strong) UIView  *leftPanel;
@property (nonatomic, strong) UIView  *rightDock;
@property (nonatomic, strong) UIView  *contentArea;
@property (nonatomic, strong) NSArray<SRFXDockButton *> *dockBtns;
@property (nonatomic, strong) UITextView  *lineNumbers;
@property (nonatomic, strong) NSMutableArray<NSString *> *savedScripts;
@property (nonatomic, strong) UITableView *savedScriptTable;
@property (nonatomic, strong) UILabel     *savedEmptyLabel;
@property (nonatomic, strong) UISearchBar             *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel                 *sectionLabel;
@property (nonatomic, strong) UILabel                 *emptyLabel;
@property (nonatomic, assign) BOOL panelVisible;
@end

@implementation SRFXMainViewController

- (CAGradientLayer *)ppGrad:(CGRect)f {
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
    self.savedScripts = [NSMutableArray array];
    self.scripts      = [NSMutableArray array];
    self.consoleText  = [NSMutableString string];
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:@"SRFXSaved"];
    if (saved) [self.savedScripts addObjectsFromArray:saved];

    [self buildFloatButton];
    [self buildPanel];
    [self buildLeftPanel];
    [self buildRightDock];
    [self buildContentArea];
    [self buildEditorTab];
    [self buildHubTab];
    [self buildConsoleTab];

    self.panelVisible = NO;
    self.panel.hidden = YES;
    self.panel.alpha  = 0;
    [self switchToTab:0];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPrint:)    name:@"SRFXPrint"      object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onError:)    name:@"SRFXError"      object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLoadScript:) name:@"SRFXLoadScript" object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat sw = UIScreen.mainScreen.bounds.size.width;
    CGFloat sh = UIScreen.mainScreen.bounds.size.height;
    self.panel.frame = CGRectMake((sw - PANEL_W)/2, (sh - PANEL_H)/2, PANEL_W, PANEL_H);
    [self relayout];
}

- (void)buildFloatButton {
    self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatBtn.frame = CGRectMake(20, 100, 52, 52);
    self.floatBtn.layer.cornerRadius  = 26;
    self.floatBtn.layer.masksToBounds = YES;
    self.floatBtn.layer.shadowColor   = SRFX_PURPLE.CGColor;
    self.floatBtn.layer.shadowOpacity = 0.8;
    self.floatBtn.layer.shadowRadius  = 10;
    self.floatBtn.layer.shadowOffset  = CGSizeZero;
    CAGradientLayer *g = [self ppGrad:CGRectMake(0,0,52,52)];
    g.cornerRadius = 26;
    [self.floatBtn.layer insertSublayer:g atIndex:0];
    [self.floatBtn setTitle:@"S" forState:UIControlStateNormal];
    [self.floatBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.floatBtn addTarget:self action:@selector(togglePanel)
            forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragBtn:)];
    [self.floatBtn addGestureRecognizer:pan];
    [self.view addSubview:self.floatBtn];
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
    pulse.fromValue = @6; pulse.toValue = @18;
    pulse.duration  = 1.6; pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [self.floatBtn.layer addAnimation:pulse forKey:@"glow"];
}

- (void)dragBtn:(UIPanGestureRecognizer *)gr {
    CGPoint t = [gr translationInView:self.view];
    self.floatBtn.center = CGPointMake(self.floatBtn.center.x + t.x, self.floatBtn.center.y + t.y);
    [gr setTranslation:CGPointZero inView:self.view];
}

- (void)buildPanel {
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0,0,PANEL_W,PANEL_H)];
    self.panel.backgroundColor     = SRFX_BG;
    self.panel.layer.cornerRadius  = 18;
    self.panel.layer.masksToBounds = YES;
    self.panel.layer.borderWidth   = 1.2;
    self.panel.layer.borderColor   = [UIColor colorWithRed:0.53 green:0.17 blue:0.77 alpha:0.7].CGColor;
    self.panel.layer.shadowColor   = SRFX_PURPLE.CGColor;
    self.panel.layer.shadowOpacity = 0.45;
    self.panel.layer.shadowRadius  = 28;
    self.panel.layer.shadowOffset  = CGSizeZero;
    [self.view addSubview:self.panel];
}

- (void)buildLeftPanel {
    self.leftPanel = [[UIView alloc] init];
    self.leftPanel.backgroundColor = SRFX_SURFACE;
    self.leftPanel.tag = 200;
    [self.panel addSubview:self.leftPanel];

    UILabel *iconLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 12, 24, 24)];
    iconLbl.text = @"< >"; iconLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    iconLbl.textColor = SRFX_PURPLE; iconLbl.textAlignment = NSTextAlignmentCenter;
    iconLbl.backgroundColor = [UIColor colorWithRed:0.53 green:0.17 blue:0.77 alpha:0.2];
    iconLbl.layer.cornerRadius = 6; iconLbl.layer.masksToBounds = YES;
    [self.leftPanel addSubview:iconLbl];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(42, 12, 120, 24)];
    title.text = @"Editor"; title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    title.textColor = SRFX_TEXT;
    [self.leftPanel addSubview:title];

    UIView *div1 = [[UIView alloc] initWithFrame:CGRectMake(0, 44, LEFT_W, 1)];
    div1.backgroundColor = SRFX_BORDER;
    [self.leftPanel addSubview:div1];

    UILabel *tabsHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, 52, 60, 16)];
    tabsHdr.text = @"Tabs"; tabsHdr.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    tabsHdr.textColor = SRFX_MUTED;
    [self.leftPanel addSubview:tabsHdr];

    UIView *tabPill = [[UIView alloc] initWithFrame:CGRectMake(8, 74, LEFT_W - 16, 30)];
    tabPill.backgroundColor = [UIColor colorWithRed:0.53 green:0.17 blue:0.77 alpha:0.2];
    tabPill.layer.cornerRadius = 8; tabPill.layer.borderWidth = 1;
    tabPill.layer.borderColor = SRFX_BORDER.CGColor;
    [self.leftPanel addSubview:tabPill];

    UILabel *tabIcon = [[UILabel alloc] initWithFrame:CGRectMake(8, 5, 20, 20)];
    tabIcon.text = @"◻"; tabIcon.font = [UIFont systemFontOfSize:12];
    tabIcon.textColor = SRFX_MUTED;
    [tabPill addSubview:tabIcon];

    UILabel *tabName = [[UILabel alloc] initWithFrame:CGRectMake(28, 5, 100, 20)];
    tabName.text = @"New tab"; tabName.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    tabName.textColor = SRFX_TEXT;
    [tabPill addSubview:tabName];

    UILabel *tabX = [[UILabel alloc] initWithFrame:CGRectMake(LEFT_W - 42, 5, 20, 20)];
    tabX.text = @"×"; tabX.font = [UIFont systemFontOfSize:14]; tabX.textColor = SRFX_MUTED;
    tabX.textAlignment = NSTextAlignmentCenter;
    [tabPill addSubview:tabX];

    UIView *div2 = [[UIView alloc] initWithFrame:CGRectMake(0, 112, LEFT_W, 1)];
    div2.backgroundColor = SRFX_BORDER;
    [self.leftPanel addSubview:div2];

    UILabel *savedHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, 120, 110, 16)];
    savedHdr.text = @"Saved scripts";
    savedHdr.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    savedHdr.textColor = SRFX_MUTED;
    [self.leftPanel addSubview:savedHdr];

    self.savedScriptTable = [[UITableView alloc] init];
    self.savedScriptTable.backgroundColor = UIColor.clearColor;
    self.savedScriptTable.separatorStyle  = UITableViewCellSeparatorStyleNone;
    self.savedScriptTable.showsVerticalScrollIndicator = NO;
    self.savedScriptTable.delegate   = self;
    self.savedScriptTable.dataSource = self;
    self.savedScriptTable.tag = 210;
    [self.leftPanel addSubview:self.savedScriptTable];

    self.savedEmptyLabel = [[UILabel alloc] init];
    self.savedEmptyLabel.text      = @"No saved scripts";
    self.savedEmptyLabel.font      = [UIFont systemFontOfSize:11];
    self.savedEmptyLabel.textColor = [SRFX_MUTED colorWithAlphaComponent:0.5];
    self.savedEmptyLabel.textAlignment = NSTextAlignmentCenter;
    self.savedEmptyLabel.tag = 211;
    [self.leftPanel addSubview:self.savedEmptyLabel];

    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragPanel:)];
    [self.leftPanel addGestureRecognizer:drag];
}

- (void)buildRightDock {
    self.rightDock = [[UIView alloc] init];
    self.rightDock.backgroundColor = SRFX_SURFACE;
    self.rightDock.tag = 300;
    [self.panel addSubview:self.rightDock];

    UIView *border = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, PANEL_H)];
    border.backgroundColor = SRFX_BORDER; border.tag = 301;
    [self.rightDock addSubview:border];

    NSArray *icons = @[@"</>", @"◉", @"⊟"];
    NSMutableArray *btns = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)icons.count; i++) {
        SRFXDockButton *btn = [SRFXDockButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(6, 18 + i * 54, DOCK_W - 12, 44);
        btn.layer.cornerRadius = 10;
        btn.titleLabel.font    = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [btn setTitle:icons[i] forState:UIControlStateNormal];
        btn.tag = i;
        [btn addTarget:self action:@selector(dockTap:) forControlEvents:UIControlEventTouchUpInside];
        btn.dockSelected = (i == 0);
        [self.rightDock addSubview:btn];
        [btns addObject:btn];
    }
    self.dockBtns = [btns copy];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.tag = 399;
    closeBtn.frame = CGRectMake(6, PANEL_H - 52, DOCK_W - 12, 40);
    closeBtn.layer.cornerRadius  = 20;
    closeBtn.layer.masksToBounds = YES;
    CAGradientLayer *cg = [self ppGrad:CGRectMake(0,0,DOCK_W-12,40)];
    cg.cornerRadius = 20;
    [closeBtn.layer insertSublayer:cg atIndex:0];
    [closeBtn setTitle:@"×" forState:UIControlStateNormal];
    [closeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightLight];
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.rightDock addSubview:closeBtn];
}

- (void)buildContentArea {
    self.contentArea = [[UIView alloc] init];
    self.contentArea.backgroundColor = SRFX_BG;
    self.contentArea.clipsToBounds   = YES;
    self.contentArea.tag = 400;
    [self.panel addSubview:self.contentArea];
}

- (void)buildEditorTab {
    self.lineNumbers = [[UITextView alloc] init];
    self.lineNumbers.backgroundColor    = SRFX_SURFACE;
    self.lineNumbers.textColor          = [SRFX_MUTED colorWithAlphaComponent:0.6];
    self.lineNumbers.font               = [UIFont fontWithName:@"Menlo" size:12];
    self.lineNumbers.editable           = NO;
    self.lineNumbers.scrollEnabled      = NO;
    self.lineNumbers.textAlignment      = NSTextAlignmentRight;
    self.lineNumbers.textContainerInset = UIEdgeInsetsMake(10, 4, 10, 6);
    self.lineNumbers.text               = @"1\n2";
    self.lineNumbers.tag = 401;
    [self.contentArea addSubview:self.lineNumbers];

    self.editor = [[UITextView alloc] init];
    self.editor.backgroundColor        = SRFX_BG;
    self.editor.textColor              = SRFX_TEXT;
    self.editor.font                   = [UIFont fontWithName:@"Menlo" size:13];
    self.editor.text                   = @"-- XZX Executor\nprint(\"Ready\")";
    self.editor.autocorrectionType     = UITextAutocorrectionTypeNo;
    self.editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.editor.smartQuotesType        = UITextSmartQuotesTypeNo;
    self.editor.textContainerInset     = UIEdgeInsetsMake(10, 8, 10, 8);
    self.editor.tag = 402;
    [self.contentArea addSubview:self.editor];

    UIView *toolbar = [[UIView alloc] init];
    toolbar.backgroundColor = SRFX_SURFACE;
    toolbar.tag = 403;
    [self.contentArea addSubview:toolbar];

    UIView *tbDiv = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2000, 1)];
    tbDiv.backgroundColor = SRFX_BORDER;
    [toolbar addSubview:tbDiv];

    UIButton *execBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    execBtn.tag = 404; execBtn.layer.cornerRadius = 8; execBtn.layer.masksToBounds = YES;
    [execBtn setTitle:@"▶  Execute" forState:UIControlStateNormal];
    [execBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    execBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [execBtn.layer insertSublayer:[self ppGrad:CGRectMake(0,0,108,34)] atIndex:0];
    [execBtn addTarget:self action:@selector(execute) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:execBtn];

    UIButton *clrBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    clrBtn.tag = 405; clrBtn.layer.cornerRadius = 8;
    clrBtn.backgroundColor = [UIColor colorWithRed:1 green:0.1 blue:0.1 alpha:0.18];
    clrBtn.layer.borderColor = [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:0.4].CGColor;
    clrBtn.layer.borderWidth = 1;
    [clrBtn setTitle:@"Clear" forState:UIControlStateNormal];
    [clrBtn setTitleColor:[UIColor colorWithRed:1 green:0.5 blue:0.5 alpha:1] forState:UIControlStateNormal];
    clrBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [clrBtn addTarget:self action:@selector(clearEditor) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:clrBtn];

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    saveBtn.tag = 406; saveBtn.layer.cornerRadius = 8;
    saveBtn.backgroundColor = SRFX_SURFACE2;
    saveBtn.layer.borderColor = SRFX_BORDER.CGColor; saveBtn.layer.borderWidth = 1;
    [saveBtn setTitle:@"Save" forState:UIControlStateNormal];
    [saveBtn setTitleColor:SRFX_MUTED forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [saveBtn addTarget:self action:@selector(saveScript) forControlEvents:UIControlEventTouchUpInside];
    [toolbar addSubview:saveBtn];
}

- (void)buildHubTab {
    UIView *hubHdr = [[UIView alloc] init];
    hubHdr.backgroundColor = SRFX_SURFACE; hubHdr.tag = 501;
    [self.contentArea addSubview:hubHdr];
    UIView *hDiv = [[UIView alloc] initWithFrame:CGRectMake(0, 43, 2000, 1)];
    hDiv.backgroundColor = SRFX_BORDER;
    [hubHdr addSubview:hDiv];

    UILabel *rblx = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 26, 26)];
    rblx.text = @"◑"; rblx.font = [UIFont boldSystemFontOfSize:18];
    rblx.textColor = UIColor.whiteColor; rblx.textAlignment = NSTextAlignmentCenter;
    rblx.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1];
    rblx.layer.cornerRadius = 6; rblx.layer.masksToBounds = YES;
    [hubHdr addSubview:rblx];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder  = @"Search for scripts";
    self.searchBar.barStyle     = UIBarStyleBlack;
    self.searchBar.delegate     = self;
    self.searchBar.tintColor    = SRFX_PINK;
    self.searchBar.barTintColor = SRFX_SURFACE;
    self.searchBar.searchTextField.backgroundColor = SRFX_SURFACE2;
    self.searchBar.searchTextField.textColor       = SRFX_TEXT;
    self.searchBar.searchTextField.font            = [UIFont systemFontOfSize:13];
    self.searchBar.searchTextField.tintColor       = SRFX_PINK;
    self.searchBar.tag = 502;
    [hubHdr addSubview:self.searchBar];

    self.sectionLabel = [[UILabel alloc] init];
    self.sectionLabel.text      = @"Trending scripts";
    self.sectionLabel.font      = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.sectionLabel.textColor = SRFX_TEXT; self.sectionLabel.tag = 503;
    [self.contentArea addSubview:self.sectionLabel];

    UILabel *sub = [[UILabel alloc] init];
    sub.text = @"The top scripts featured for today.";
    sub.font = [UIFont systemFontOfSize:10]; sub.textColor = SRFX_MUTED; sub.tag = 504;
    [self.contentArea addSubview:sub];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = SRFX_PINK; self.spinner.hidesWhenStopped = YES; self.spinner.tag = 505;
    [self.contentArea addSubview:self.spinner];

    self.scriptList = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.scriptList.backgroundColor = UIColor.clearColor;
    self.scriptList.separatorStyle  = UITableViewCellSeparatorStyleNone;
    self.scriptList.delegate        = self;
    self.scriptList.dataSource      = self;
    self.scriptList.rowHeight       = 94;
    self.scriptList.contentInset    = UIEdgeInsetsMake(0, 0, 8, 0);
    self.scriptList.tag = 506;
    [self.contentArea addSubview:self.scriptList];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text          = @"Loading scripts...";
    self.emptyLabel.font          = [UIFont systemFontOfSize:13];
    self.emptyLabel.textColor     = SRFX_MUTED;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 2; self.emptyLabel.tag = 507;
    [self.contentArea addSubview:self.emptyLabel];

    [self loadTrending];
}

- (void)buildConsoleTab {
    self.consoleView = [[UITextView alloc] init];
    self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.05 alpha:1];
    self.consoleView.font      = [UIFont fontWithName:@"Menlo" size:12];
    self.consoleView.editable  = NO;
    self.consoleView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    self.consoleView.tag = 601;
    [self.contentArea addSubview:self.consoleView];

    UIButton *clrBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    clrBtn.layer.cornerRadius = 7; clrBtn.backgroundColor = SRFX_SURFACE2;
    clrBtn.layer.borderColor = SRFX_BORDER.CGColor; clrBtn.layer.borderWidth = 1;
    [clrBtn setTitle:@"Clear Console" forState:UIControlStateNormal];
    [clrBtn setTitleColor:SRFX_MUTED forState:UIControlStateNormal];
    clrBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [clrBtn addTarget:self action:@selector(clearConsole) forControlEvents:UIControlEventTouchUpInside];
    clrBtn.tag = 602;
    [self.contentArea addSubview:clrBtn];
}

- (void)relayout {
    CGFloat pw = self.panel.bounds.size.width;
    CGFloat ph = self.panel.bounds.size.height;
    BOOL isEditor = (self.selectedTab == 0);
    CGFloat lpW = isEditor ? LEFT_W : 0;
    CGFloat cw  = pw - lpW - DOCK_W;
    CGFloat ch  = ph;

    self.leftPanel.frame  = CGRectMake(0, 0, LEFT_W, ph);
    self.leftPanel.hidden = !isEditor;
    self.savedScriptTable.frame  = CGRectMake(0, 140, LEFT_W, ph - 148);
    self.savedEmptyLabel.frame   = CGRectMake(12, 160, LEFT_W - 24, 40);
    self.savedEmptyLabel.hidden  = (self.savedScripts.count > 0);

    self.rightDock.frame = CGRectMake(pw - DOCK_W, 0, DOCK_W, ph);
    [self.rightDock viewWithTag:301].frame = CGRectMake(0, 0, 1, ph);
    UIView *closeBtn = [self.rightDock viewWithTag:399];
    closeBtn.frame = CGRectMake(6, ph - 52, DOCK_W - 12, 40);
    for (CALayer *l in closeBtn.layer.sublayers)
        if ([l isKindOfClass:[CAGradientLayer class]]) l.frame = closeBtn.bounds;

    self.contentArea.frame = CGRectMake(lpW, 0, cw, ch);

    // Editor
    CGFloat tbH = 50, lnW = 28;
    [self.contentArea viewWithTag:401].frame = CGRectMake(0, 0, lnW, ch - tbH);
    [self.contentArea viewWithTag:402].frame = CGRectMake(lnW, 0, cw - lnW, ch - tbH);
    UIView *tb = [self.contentArea viewWithTag:403];
    tb.frame = CGRectMake(0, ch - tbH, cw, tbH);
    UIView *exec = [tb viewWithTag:404], *clr = [tb viewWithTag:405], *save = [tb viewWithTag:406];
    exec.frame = CGRectMake(10, 8, 108, 34);
    clr.frame  = CGRectMake(126, 8, 72, 34);
    save.frame = CGRectMake(206, 8, 64, 34);
    for (UIView *b in @[exec, clr, save])
        for (CALayer *l in b.layer.sublayers)
            if ([l isKindOfClass:[CAGradientLayer class]]) l.frame = b.bounds;

    // Hub
    [self.contentArea viewWithTag:501].frame = CGRectMake(0, 0, cw, 44);
    [self.contentArea viewWithTag:502].frame = CGRectMake(40, 4, cw - 56, 38);
    [self.contentArea viewWithTag:503].frame = CGRectMake(12, 50, cw - 24, 18);
    [self.contentArea viewWithTag:504].frame = CGRectMake(12, 68, cw - 24, 14);
    self.spinner.center = CGPointMake(cw/2, ch/2);
    [self.contentArea viewWithTag:506].frame = CGRectMake(0, 86, cw, ch - 86);
    [self.contentArea viewWithTag:507].frame = CGRectMake(20, ch/2 - 20, cw - 40, 40);

    // Console
    [self.contentArea viewWithTag:601].frame = CGRectMake(0, 0, cw, ch - 42);
    [self.contentArea viewWithTag:602].frame = CGRectMake(cw/2 - 64, ch - 36, 128, 28);
}

- (void)dockTap:(UIButton *)sender { [self switchToTab:sender.tag]; }

- (void)switchToTab:(NSInteger)idx {
    self.selectedTab = idx;
    for (SRFXDockButton *b in self.dockBtns) b.dockSelected = (b.tag == idx);
    for (NSNumber *t in @[@401,@402,@403])
        [self.contentArea viewWithTag:t.integerValue].hidden = (idx != 0);
    for (NSNumber *t in @[@501,@502,@503,@504,@505,@506,@507])
        [self.contentArea viewWithTag:t.integerValue].hidden = (idx != 1);
    for (NSNumber *t in @[@601,@602])
        [self.contentArea viewWithTag:t.integerValue].hidden = (idx != 2);
    self.leftPanel.hidden = (idx != 0);
    [self relayout];
    if (idx == 1 && self.scripts.count == 0) [self loadTrending];
}

- (void)togglePanel {
    self.panelVisible = !self.panelVisible;
    self.panel.hidden = NO;
    [UIView animateWithDuration:0.3 delay:0
        usingSpringWithDamping:0.80 initialSpringVelocity:0.3
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
            self.panel.alpha     = self.panelVisible ? 1 : 0;
            self.panel.transform = self.panelVisible ? CGAffineTransformIdentity
                                                     : CGAffineTransformMakeScale(0.88, 0.88);
            self.floatBtn.transform = self.panelVisible
                ? CGAffineTransformMakeRotation(M_PI_4 * 0.5)
                : CGAffineTransformIdentity;
        } completion:^(BOOL f) {
            if (!self.panelVisible) self.panel.hidden = YES;
        }];
}

- (void)closePanel { self.panelVisible = YES; [self togglePanel]; }

- (void)dragPanel:(UIPanGestureRecognizer *)gr {
    CGPoint t = [gr translationInView:self.view];
    self.panel.center = CGPointMake(self.panel.center.x + t.x, self.panel.center.y + t.y);
    [gr setTranslation:CGPointZero inView:self.view];
}

- (void)loadTrending {
    self.emptyLabel.text   = @"Loading scripts...";
    self.emptyLabel.hidden = NO;
    [self.spinner startAnimating];
    [SRFXScriptBlox fetchTrending:^(NSArray *scripts) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scripts removeAllObjects];
            [self.scripts addObjectsFromArray:scripts];
            [self.scriptList reloadData];
            [self.spinner stopAnimating];
            self.sectionLabel.text = @"Trending scripts";
            self.emptyLabel.hidden = (scripts.count > 0);
            if (!scripts.count) self.emptyLabel.text = @"No scripts found.\nCheck your connection.";
        });
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb {
    [sb resignFirstResponder];
    NSString *q = [sb.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!q.length) { [self loadTrending]; return; }
    self.emptyLabel.text = @"Searching..."; self.emptyLabel.hidden = NO;
    [self.spinner startAnimating];
    [SRFXScriptBlox search:q completion:^(NSArray *r) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scripts removeAllObjects];
            [self.scripts addObjectsFromArray:r];
            [self.scriptList reloadData];
            [self.spinner stopAnimating];
            self.sectionLabel.text = [NSString stringWithFormat:@"Results for \"%@\"", q];
            self.emptyLabel.hidden = (r.count > 0);
            if (!r.count) self.emptyLabel.text = @"No results found.";
        });
    }];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)sb {
    sb.text = @""; [sb resignFirstResponder]; [self loadTrending];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return (t.tag == 506) ? self.scripts.count : self.savedScripts.count;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (t.tag == 506) {
        SRFXScriptCard *cell = [t dequeueReusableCellWithIdentifier:@"card"];
        if (!cell) cell = [[SRFXScriptCard alloc] initWithStyle:0 reuseIdentifier:@"card"];
        [cell configureWithData:self.scripts[ip.row] index:ip.row];
        cell.loadBtn.tag = ip.row;
        [cell.loadBtn removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [cell.loadBtn addTarget:self action:@selector(loadCard:) forControlEvents:UIControlEventTouchUpInside];
        return cell;
    }
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:@"saved"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"saved"];
        cell.backgroundColor = UIColor.clearColor;
        cell.selectionStyle  = UITableViewCellSelectionStyleNone;
        cell.textLabel.font  = [UIFont systemFontOfSize:12];
        cell.textLabel.textColor  = SRFX_TEXT;
        cell.textLabel.numberOfLines = 1;
    }
    NSString *first = [self.savedScripts[ip.row] componentsSeparatedByString:@"\n"].firstObject ?: @"Script";
    first = [first stringByReplacingOccurrencesOfString:@"-- " withString:@""];
    if (first.length > 26) first = [[first substringToIndex:26] stringByAppendingString:@"…"];
    cell.imageView.image    = [UIImage systemImageNamed:@"star"];
    cell.imageView.tintColor = [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1];
    cell.textLabel.text     = first.length ? first : @"Script";
    return cell;
}

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip {
    return (t.tag == 506) ? 94 : 36;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    if (t.tag == 210) {
        self.editor.text = self.savedScripts[ip.row];
        [self updateLineNumbers];
        [self switchToTab:0];
    }
}

- (void)loadCard:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < (NSInteger)self.scripts.count)
        [self fetchAndLoad:self.scripts[idx][@"slug"]];
}

- (void)fetchAndLoad:(NSString *)slug {
    if (!slug.length) return;
    [self.spinner startAnimating];
    [SRFXScriptBlox fetchScript:slug completion:^(NSString *code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (code.length) {
                self.editor.text = code;
                [self updateLineNumbers];
                [self switchToTab:0];
            } else {
                self.emptyLabel.text   = @"Failed to load script.";
                self.emptyLabel.hidden = NO;
            }
        });
    }];
}

- (void)execute {
    if (!self.editor.text.length) return;
    UIView *tb  = [self.contentArea viewWithTag:403];
    UIView *btn = [tb viewWithTag:404];
    [UIView animateWithDuration:0.08 animations:^{ btn.alpha = 0.45; }
        completion:^(BOOL f){ [UIView animateWithDuration:0.2 animations:^{ btn.alpha = 1; }]; }];
    SRFXLuaExecute(self.editor.text.UTF8String);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.consoleText.length) [self switchToTab:2];
    });
}

- (void)clearEditor { self.editor.text = @""; [self updateLineNumbers]; }

- (void)saveScript {
    if (!self.editor.text.length) return;
    [self.savedScripts insertObject:self.editor.text atIndex:0];
    if (self.savedScripts.count > 30) [self.savedScripts removeLastObject];
    [[NSUserDefaults standardUserDefaults] setObject:[self.savedScripts copy] forKey:@"SRFXSaved"];
    [self.savedScriptTable reloadData];
    self.savedEmptyLabel.hidden = YES;
    [self showToast:@"✓  Saved"];
}

- (void)updateLineNumbers {
    NSUInteger lines = [self.editor.text componentsSeparatedByString:@"\n"].count;
    NSMutableString *nums = [NSMutableString string];
    for (NSUInteger i = 1; i <= MAX(lines, 2); i++)
        [nums appendFormat:@"%lu\n", (unsigned long)i];
    self.lineNumbers.text = nums;
}

- (void)showToast:(NSString *)msg {
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(0,0,130,34)];
    t.text = msg; t.textColor = UIColor.whiteColor;
    t.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    t.textAlignment = NSTextAlignmentCenter;
    t.backgroundColor = SRFX_PURPLE;
    t.layer.cornerRadius = 10; t.layer.masksToBounds = YES;
    t.center = CGPointMake(self.contentArea.bounds.size.width/2, 22);
    [self.contentArea addSubview:t];
    [UIView animateWithDuration:0.4 delay:1.2 options:0
        animations:^{ t.alpha = 0; }
        completion:^(BOOL f){ [t removeFromSuperview]; }];
}

- (void)clearConsole {
    self.consoleText = [NSMutableString string];
    self.consoleView.attributedText = nil;
    self.consoleView.text = @"";
}

- (void)onPrint:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = [NSString stringWithFormat:@"[OUT] %@\n", note.object];
        NSMutableAttributedString *attr = self.consoleView.attributedText
            ? [self.consoleView.attributedText mutableCopy]
            : [[NSMutableAttributedString alloc] init];
        [attr appendAttributedString:[[NSAttributedString alloc]
            initWithString:msg attributes:@{
                NSForegroundColorAttributeName: SRFX_GREEN,
                NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:12]
            }]];
        self.consoleView.attributedText = attr;
        [self.consoleText appendString:msg];
        [self.consoleView scrollRangeToVisible:NSMakeRange(self.consoleText.length, 0)];
    });
}

- (void)onError:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *msg = [NSString stringWithFormat:@"[ERR] %@\n", note.object];
        NSMutableAttributedString *attr = self.consoleView.attributedText
            ? [self.consoleView.attributedText mutableCopy]
            : [[NSMutableAttributedString alloc] init];
        [attr appendAttributedString:[[NSAttributedString alloc]
            initWithString:msg attributes:@{
                NSForegroundColorAttributeName: SRFX_PINK,
                NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:12]
            }]];
        self.consoleView.attributedText = attr;
        [self.consoleText appendString:msg];
    });
}

- (void)onLoadScript:(NSNotification *)note {
    NSString *code = note.object;
    if (!code) return;
    self.editor.text = code;
    [self updateLineNumbers];
    [self switchToTab:0];
    if (!self.panelVisible) [self togglePanel];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
