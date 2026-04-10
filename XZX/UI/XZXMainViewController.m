#import <UIKit/UIKit.h>

@interface XZXMainViewController : UIViewController
@end

@implementation XZXMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    // Floating drag button (toggle the NeonWindow)
    UIButton *toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    toggleBtn.frame = CGRectMake(20, 80, 52, 52);
    toggleBtn.backgroundColor = [UIColor colorWithRed:0.45 green:0.20 blue:0.85 alpha:0.95];
    toggleBtn.layer.cornerRadius = 26;
    toggleBtn.layer.shadowColor  = [UIColor colorWithRed:0.65 green:0.35 blue:1 alpha:1].CGColor;
    toggleBtn.layer.shadowOpacity = 0.8;
    toggleBtn.layer.shadowRadius  = 10;
    toggleBtn.layer.shadowOffset  = CGSizeZero;
    [toggleBtn setTitle:@"⚡" forState:UIControlStateNormal];
    toggleBtn.titleLabel.font = [UIFont systemFontOfSize:24];
    [toggleBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBtn:)];
    [toggleBtn addGestureRecognizer:pan];

    [self.view addSubview:toggleBtn];
    _toggleBtn = toggleBtn;

    // The main panel (hidden by default, shown on tap)
    [self buildPanel];
    _panelVisible = NO;
    _panel.hidden = YES;
}

- (void)buildPanel {
    CGRect screen = UIScreen.mainScreen.bounds;
    CGFloat pw = MIN(screen.size.width - 40, 440);
    CGFloat ph = MIN(screen.size.height - 120, 520);
    CGFloat px = (screen.size.width  - pw) / 2;
    CGFloat py = (screen.size.height - ph) / 2;

    _panel = [[UIView alloc] initWithFrame:CGRectMake(px, py, pw, ph)];
    _panel.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.11 alpha:0.97];
    _panel.layer.cornerRadius = 18;
    _panel.layer.borderWidth  = 1.2;
    _panel.layer.borderColor  = [UIColor colorWithRed:0.55 green:0.25 blue:0.95 alpha:0.7].CGColor;
    _panel.layer.shadowColor  = [UIColor colorWithRed:0.65 green:0.35 blue:1 alpha:1].CGColor;
    _panel.layer.shadowOpacity = 0.6;
    _panel.layer.shadowRadius  = 20;
    _panel.layer.shadowOffset  = CGSizeZero;
    [self.view addSubview:_panel];

    // Title bar
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pw, 44)];
    titleBar.backgroundColor = [UIColor colorWithRed:0.45 green:0.20 blue:0.85 alpha:1];
    titleBar.layer.cornerRadius = 18;
    titleBar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [_panel addSubview:titleBar];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, pw - 60, 44)];
    titleLbl.text = @"⚡ XZX Executor";
    titleLbl.textColor = UIColor.whiteColor;
    titleLbl.font = [UIFont boldSystemFontOfSize:15];
    [titleBar addSubview:titleLbl];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(pw - 44, 0, 44, 44);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:closeBtn];

    // Drag title bar
    UIPanGestureRecognizer *panPanel = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPanel:)];
    [titleBar addGestureRecognizer:panPanel];

    // Tab bar
    NSArray *tabs = @[@"Editor", @"Hub", @"Saved"];
    _tabButtons = [NSMutableArray array];
    CGFloat tw = pw / tabs.count;
    for (int i = 0; i < tabs.count; i++) {
        UIButton *tab = [UIButton buttonWithType:UIButtonTypeSystem];
        tab.frame = CGRectMake(i * tw, 44, tw, 38);
        [tab setTitle:tabs[i] forState:UIControlStateNormal];
        [tab setTitleColor:(i == 0 ? UIColor.whiteColor : [UIColor colorWithWhite:1 alpha:0.4]) forState:UIControlStateNormal];
        tab.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        tab.tag = i;
        [tab addTarget:self action:@selector(switchTab:) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:tab];
        [_tabButtons addObject:tab];
    }

    // Tab indicator line
    _tabLine = [[UIView alloc] initWithFrame:CGRectMake(0, 82, tw, 2)];
    _tabLine.backgroundColor = [UIColor colorWithRed:0.65 green:0.35 blue:1 alpha:1];
    [_panel addSubview:_tabLine];

    // Content area
    CGRect content = CGRectMake(0, 84, pw, ph - 84);

    // ── Editor tab ──
    _editorView = [[UIView alloc] initWithFrame:content];
    _editorView.hidden = NO;
    [_panel addSubview:_editorView];

    _textView = [[UITextView alloc] initWithFrame:CGRectMake(10, 8, pw - 20, ph - 84 - 54)];
    _textView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.10 alpha:1];
    _textView.textColor = [UIColor colorWithRed:0.75 green:0.95 blue:0.75 alpha:1];
    _textView.font = [UIFont fontWithName:@"Menlo" size:13] ?: [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    _textView.text = @"-- XZX Executor\nprint(\"Hello from XZX!\")";
    _textView.layer.cornerRadius = 8;
    _textView.keyboardType = UIKeyboardTypeDefault;
    _textView.autocorrectionType = UITextAutocorrectionTypeNo;
    _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [_editorView addSubview:_textView];

    CGFloat btnY = ph - 84 - 42;
    UIButton *execBtn = [self makeButton:@"▶  Execute" color:[UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1]];
    execBtn.frame = CGRectMake(10, btnY, (pw - 30) / 2, 36);
    [execBtn addTarget:self action:@selector(executeScript) forControlEvents:UIControlEventTouchUpInside];
    [_editorView addSubview:execBtn];

    UIButton *clearBtn = [self makeButton:@"🗑  Clear" color:[UIColor colorWithRed:0.5 green:0.1 blue:0.1 alpha:1]];
    clearBtn.frame = CGRectMake(20 + (pw - 30) / 2, btnY, (pw - 30) / 2, 36);
    [clearBtn addTarget:self action:@selector(clearScript) forControlEvents:UIControlEventTouchUpInside];
    [_editorView addSubview:clearBtn];

    // ── Hub tab ──
    _hubView = [[UIView alloc] initWithFrame:content];
    _hubView.hidden = YES;
    [_panel addSubview:_hubView];

    UILabel *hubPlaceholder = [[UILabel alloc] initWithFrame:_hubView.bounds];
    hubPlaceholder.text = @"Script Hub";
    hubPlaceholder.textColor = [UIColor colorWithWhite:1 alpha:0.3];
    hubPlaceholder.textAlignment = NSTextAlignmentCenter;
    hubPlaceholder.font = [UIFont systemFontOfSize:16];
    [_hubView addSubview:hubPlaceholder];

    // ── Saved tab ──
    _savedView = [[UIView alloc] initWithFrame:content];
    _savedView.hidden = YES;
    [_panel addSubview:_savedView];

    UILabel *savedPlaceholder = [[UILabel alloc] initWithFrame:_savedView.bounds];
    savedPlaceholder.text = @"No saved scripts";
    savedPlaceholder.textColor = [UIColor colorWithWhite:1 alpha:0.3];
    savedPlaceholder.textAlignment = NSTextAlignmentCenter;
    savedPlaceholder.font = [UIFont systemFontOfSize:16];
    [_savedView addSubview:savedPlaceholder];

    // Listen for scripts loaded from hub
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadScript:)
                                                 name:@"LoadScript"
                                               object:nil];
}

- (UIButton *)makeButton:(NSString *)title color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.backgroundColor = color;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    btn.layer.cornerRadius = 8;
    return btn;
}

- (void)togglePanel {
    _panelVisible = !_panelVisible;
    [UIView animateWithDuration:0.22 animations:^{
        _panel.hidden  = !_panelVisible;
        _panel.alpha   = _panelVisible ? 1 : 0;
        _panel.transform = _panelVisible ? CGAffineTransformIdentity
                                         : CGAffineTransformMakeScale(0.92, 0.92);
    }];
}

- (void)switchTab:(UIButton *)sender {
    NSInteger idx = sender.tag;
    _editorView.hidden = (idx != 0);
    _hubView.hidden    = (idx != 1);
    _savedView.hidden  = (idx != 2);

    CGFloat tw = _panel.bounds.size.width / _tabButtons.count;
    [UIView animateWithDuration:0.18 animations:^{
        CGRect f = _tabLine.frame;
        f.origin.x = idx * tw;
        _tabLine.frame = f;
    }];

    for (UIButton *btn in _tabButtons) {
        btn.titleLabel.alpha = (btn.tag == idx) ? 1.0 : 0.4;
        [btn setTitleColor:(btn.tag == idx ? UIColor.whiteColor : [UIColor colorWithWhite:1 alpha:0.4])
                  forState:UIControlStateNormal];
    }
}

- (void)executeScript {
    NSString *script = _textView.text;
    if (script.length == 0) return;
    // Post to bridge
    [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXExecuteScript" object:script];
}

- (void)clearScript {
    _textView.text = @"";
}

- (void)loadScript:(NSNotification *)note {
    NSString *script = note.object;
    if (script) {
        _textView.text = script;
        [self switchTab:_tabButtons[0]];
        if (!_panelVisible) [self togglePanel];
    }
}

// Drag floating button
- (void)dragBtn:(UIPanGestureRecognizer *)gr {
    CGPoint t = [gr translationInView:self.view];
    _toggleBtn.center = CGPointMake(_toggleBtn.center.x + t.x, _toggleBtn.center.y + t.y);
    [gr setTranslation:CGPointZero inView:self.view];
}

// Drag panel
- (void)dragPanel:(UIPanGestureRecognizer *)gr {
    CGPoint t = [gr translationInView:self.view];
    _panel.center = CGPointMake(_panel.center.x + t.x, _panel.center.y + t.y);
    [gr setTranslation:CGPointZero inView:self.view];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
