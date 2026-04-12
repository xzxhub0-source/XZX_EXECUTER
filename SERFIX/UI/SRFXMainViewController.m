#import "SRFXMainViewController.h"
#import "SRFXScriptBlox.h"
#include "Core/SRFXLua.h"

@interface SRFXMainViewController () <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate>
@end

@implementation SRFXMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:0.98];
    self.view.layer.cornerRadius = 16;
    self.view.layer.borderWidth = 1;
    self.view.layer.borderColor = [UIColor colorWithRed:0.3 green:0.2 blue:0.8 alpha:1.0].CGColor;

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 50)];
    header.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:1.0];
    [self.view addSubview:header];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, 200, 30)];
    title.text = @"SERFIX";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:20];
    [header addSubview:title];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.view.bounds.size.width - 50, 10, 40, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:24];
    [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    UIButton *minimizeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minimizeBtn.frame = CGRectMake(self.view.bounds.size.width - 90, 10, 40, 30);
    [minimizeBtn setTitle:@"−" forState:UIControlStateNormal];
    [minimizeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    minimizeBtn.titleLabel.font = [UIFont systemFontOfSize:30];
    [minimizeBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:minimizeBtn];

    self.tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, 50, self.view.bounds.size.width, 40)];
    self.tabBar.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
    [self.view addSubview:self.tabBar];

    NSArray *tabs = @[@"Editor", @"ScriptBlox", @"Console", @"Settings"];
    for (int i = 0; i < tabs.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(i * (self.view.bounds.size.width / tabs.count), 0, self.view.bounds.size.width / tabs.count, 40);
        [btn setTitle:tabs[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14];
        btn.tag = i;
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabBar addSubview:btn];
    }

    self.selectedTab = 0;
    [self updateTabSelection];

    self.editor = [[UITextView alloc] initWithFrame:CGRectMake(8, 98, self.view.bounds.size.width - 16, self.view.bounds.size.height - 180)];
    self.editor.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.1 alpha:1.0];
    self.editor.textColor = [UIColor whiteColor];
    self.editor.font = [UIFont fontWithName:@"Menlo" size:13];
    self.editor.text = @"print('Hello SERFIX')";
    self.editor.autocorrectionType = UITextAutocorrectionTypeNo;
    self.editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.editor.layer.borderColor = [UIColor colorWithRed:0.3 green:0.2 blue:0.8 alpha:0.5].CGColor;
    self.editor.layer.borderWidth = 1;
    self.editor.layer.cornerRadius = 6;
    [self.view addSubview:self.editor];

    self.scriptList = [[UITableView alloc] initWithFrame:self.editor.frame style:UITableViewStylePlain];
    self.scriptList.backgroundColor = self.editor.backgroundColor;
    self.scriptList.delegate = self;
    self.scriptList.dataSource = self;
    self.scriptList.separatorColor = [UIColor darkGrayColor];
    self.scriptList.hidden = YES;
    [self.view addSubview:self.scriptList];

    UIButton *execBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    execBtn.frame = CGRectMake(8, self.view.bounds.size.height - 75, 100, 40);
    [execBtn setTitle:@"Execute" forState:UIControlStateNormal];
    execBtn.backgroundColor = [UIColor colorWithRed:0.4 green:0.3 blue:0.9 alpha:1.0];
    [execBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    execBtn.layer.cornerRadius = 6;
    [execBtn addTarget:self action:@selector(execute) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:execBtn];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(116, self.view.bounds.size.height - 75, 100, 40);
    [clearBtn setTitle:@"Clear" forState:UIControlStateNormal];
    clearBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    [clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    clearBtn.layer.cornerRadius = 6;
    [clearBtn addTarget:self action:@selector(clear) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearBtn];

    UIButton *loadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    loadBtn.frame = CGRectMake(224, self.view.bounds.size.height - 75, 100, 40);
    [loadBtn setTitle:@"Load Script" forState:UIControlStateNormal];
    loadBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:1.0];
    [loadBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    loadBtn.layer.cornerRadius = 6;
    [loadBtn addTarget:self action:@selector(showScriptBlox) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:loadBtn];

    self.scripts = [NSMutableArray array];
    [self loadTrendingScripts];
}

- (void)loadTrendingScripts {
    [SRFXScriptBlox fetchTrending:^(NSArray *scripts) {
        [self.scripts removeAllObjects];
        [self.scripts addObjectsFromArray:scripts];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scriptList reloadData];
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
    [selected setTitleColor:[UIColor colorWithRed:0.6 green:0.4 blue:1.0 alpha:1.0] forState:UIControlStateNormal];

    if (self.selectedTab == 0) {
        self.editor.hidden = NO;
        self.scriptList.hidden = YES;
    } else if (self.selectedTab == 1) {
        self.editor.hidden = YES;
        self.scriptList.hidden = NO;
        if (self.scripts.count == 0) [self loadTrendingScripts];
    } else {
        self.editor.hidden = YES;
        self.scriptList.hidden = YES;
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
        cell.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.1 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    }
    NSDictionary *s = self.scripts[indexPath.row];
    cell.textLabel.text = s[@"title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"By %@ • %@", s[@"author"], s[@"game"]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *s = self.scripts[indexPath.row];
    NSString *slug = s[@"slug"];
    [SRFXScriptBlox fetchScript:slug completion:^(NSString *code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.editor.text = code;
            self.selectedTab = 0;
            [self updateTabSelection];
        });
    }];
}

- (void)execute {
    if (self.editor.text.length > 0) {
        SRFXLuaExecute(self.editor.text.UTF8String);
    }
}

- (void)clear {
    self.editor.text = @"";
}

- (void)hide {
    self.view.window.hidden = YES;
}

- (void)minimize {
    self.view.window.frame = CGRectMake(self.view.window.frame.origin.x,
                                         self.view.window.frame.origin.y,
                                         60, 60);
}

@end
