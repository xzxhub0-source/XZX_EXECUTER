#import “SRFXMainViewController.h”
#import “SRFXScriptBlox.h”
#include “Core/SRFXLua.h”

@interface SRFXMainViewController () <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UIButton *execBtn;
@property (nonatomic, strong) UIButton *clearBtn;
@property (nonatomic, strong) UIButton *loadBtn;
@end

@implementation SRFXMainViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:0.98];
  self.view.layer.cornerRadius = 16;
  self.view.layer.borderWidth = 1.2;
  self.view.layer.borderColor = [UIColor colorWithRed:0.5 green:0.3 blue:1.0 alpha:1.0].CGColor;
  
  self.header = [[UIView alloc] init];
  self.header.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:1.0];
  [self.view addSubview:self.header];
  
  UILabel *title = [[UILabel alloc] init];
  title.text = @“SERFIX”;
  title.textColor = UIColor.whiteColor;
  title.font = [UIFont boldSystemFontOfSize:22];
  title.tag = 100;
  [self.header addSubview:title];
  
  UIButton *minBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [minBtn setTitle:@“−” forState:UIControlStateNormal];
  [minBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  minBtn.titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightThin];
  [minBtn addTarget:self action:@selector(minimize) forControlEvents:UIControlEventTouchUpInside];
  minBtn.tag = 101;
  [self.header addSubview:minBtn];
  
  UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [closeBtn setTitle:@“✕” forState:UIControlStateNormal];
  [closeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  closeBtn.titleLabel.font = [UIFont systemFontOfSize:22];
  [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
  closeBtn.tag = 102;
  [self.header addSubview:closeBtn];
  
  self.tabBar = [[UIView alloc] init];
  self.tabBar.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.10 alpha:1.0];
  [self.view addSubview:self.tabBar];
  
  NSArray *tabs = @[@“Editor”, @“ScriptBlox”, @“Console”, @“Settings”];
  for (int i = 0; i < (int)tabs.count; i++) {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
  [btn setTitle:tabs[i] forState:UIControlStateNormal];
  [btn setTitleColor:UIColor.lightGrayColor forState:UIControlStateNormal];
  btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
  btn.tag = i;
  [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self.tabBar addSubview:btn];
  }
  
  self.editor = [[UITextView alloc] init];
  self.editor.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.09 alpha:1.0];
  self.editor.textColor = [UIColor colorWithRed:0.9 green:0.9 blue:1.0 alpha:1.0];
  self.editor.font = [UIFont fontWithName:@“Menlo” size:13];
  self.editor.text = @“print(‘Hello SERFIX’)”;
  self.editor.autocorrectionType = UITextAutocorrectionTypeNo;
  self.editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
  self.editor.smartQuotesType = UITextSmartQuotesTypeNo;
  self.editor.layer.borderColor = [UIColor colorWithRed:0.4 green:0.2 blue:0.9 alpha:0.5].CGColor;
  self.editor.layer.borderWidth = 1;
  self.editor.layer.cornerRadius = 8;
  [self.view addSubview:self.editor];
  
  self.scriptList = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  self.scriptList.backgroundColor = self.editor.backgroundColor;
  self.scriptList.delegate = self;
  self.scriptList.dataSource = self;
  self.scriptList.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
  self.scriptList.hidden = YES;
  self.scriptList.rowHeight = 70;
  [self.view addSubview:self.scriptList];
  
  self.searchBar = [[UISearchBar alloc] init];
  self.searchBar.delegate = self;
  self.searchBar.placeholder = @“Search ScriptBlox…”;
  self.searchBar.barStyle = UIBarStyleBlack;
  self.searchBar.searchTextField.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
  self.searchBar.searchTextField.textColor = UIColor.whiteColor;
  self.searchBar.hidden = YES;
  [self.view addSubview:self.searchBar];
  
  self.consoleView = [[UITextView alloc] init];
  self.consoleView.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];
  self.consoleView.textColor = [UIColor colorWithRed:0.5 green:1.0 blue:0.5 alpha:1.0];
  self.consoleView.font = [UIFont fontWithName:@“Menlo” size:12];
  self.consoleView.editable = NO;
  self.consoleView.hidden = YES;
  [self.view addSubview:self.consoleView];
  
  self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  self.spinner.color = [UIColor colorWithRed:0.5 green:0.3 blue:1.0 alpha:1.0];
  self.spinner.hidesWhenStopped = YES;
  [self.view addSubview:self.spinner];
  
  self.execBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.execBtn setTitle:@“Execute” forState:UIControlStateNormal];
  self.execBtn.backgroundColor = [UIColor colorWithRed:0.4 green:0.3 blue:1.0 alpha:1.0];
  [self.execBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  self.execBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
  self.execBtn.layer.cornerRadius = 8;
  [self.execBtn addTarget:self action:@selector(execute) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.execBtn];
  
  self.clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.clearBtn setTitle:@“Clear” forState:UIControlStateNormal];
  self.clearBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
  [self.clearBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  self.clearBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
  self.clearBtn.layer.cornerRadius = 8;
  [self.clearBtn addTarget:self action:@selector(clear) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.clearBtn];
  
  self.loadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.loadBtn setTitle:@“Load” forState:UIControlStateNormal];
  self.loadBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1.0];
  [self.loadBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  self.loadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
  self.loadBtn.layer.cornerRadius = 8;
  [self.loadBtn addTarget:self action:@selector(showScriptBlox) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.loadBtn];
  
  self.scripts = [NSMutableArray array];
  self.consoleText = [NSMutableString string];
  self.selectedTab = 0;
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePrint:) name:@“SRFXPrint” object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleError:) name:@“SRFXError” object:nil];
  
  [self loadTrendingScripts];
  }
- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGFloat w = self.view.bounds.size.width;
  CGFloat h = self.view.bounds.size.height;
  CGFloat tabCount = 4.0;
  
  self.header.frame = CGRectMake(0, 0, w, 55);
  [[self.header viewWithTag:100] setFrame:CGRectMake(15, 12, 150, 30)];
  [[self.header viewWithTag:101] setFrame:CGRectMake(w - 95, 10, 40, 35)];
  [[self.header viewWithTag:102] setFrame:CGRectMake(w - 50, 10, 40, 35)];
  
  self.tabBar.frame = CGRectMake(0, 55, w, 42);
  CGFloat tw = w / tabCount;
  for (UIView *v in self.tabBar.subviews) {
  if ([v isKindOfClass:[UIButton class]])
  v.frame = CGRectMake(v.tag * tw, 0, tw, 42);
  }
  
  CGRect editorFrame = CGRectMake(10, 107, w - 20, h - 195);
  self.editor.frame = editorFrame;
  self.consoleView.frame = editorFrame;
  self.searchBar.frame = CGRectMake(10, 107, w - 20, 44);
  
  if (self.selectedTab == 1)
  self.scriptList.frame = CGRectMake(10, 155, w - 20, h - 240);
  else
  self.scriptList.frame = editorFrame;
  
  self.spinner.center = CGPointMake(w / 2, 200);
  
  CGFloat btnY = h - 80;
  self.execBtn.frame = CGRectMake(10,  btnY, 95, 42);
  self.clearBtn.frame = CGRectMake(115, btnY, 95, 42);
  self.loadBtn.frame = CGRectMake(220, btnY, 95, 42);
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
  if ([v isKindOfClass:[UIButton class]])
  [(UIButton *)v setTitleColor:UIColor.lightGrayColor forState:UIControlStateNormal];
  }
  UIButton *sel = (UIButton *)[self.tabBar viewWithTag:self.selectedTab];
  [sel setTitleColor:[UIColor colorWithRed:0.5 green:0.3 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
  
  self.editor.hidden = (self.selectedTab != 0);
  self.scriptList.hidden = (self.selectedTab != 1);
  self.searchBar.hidden = (self.selectedTab != 1);
  self.consoleView.hidden = (self.selectedTab != 2);
  
  if (self.selectedTab == 1 && self.scripts.count == 0) [self loadTrendingScripts];
  [self.view setNeedsLayout];
  }
- (void)showScriptBlox {
  self.selectedTab = 1;
  [self updateTabSelection];
  }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.scripts.count;
  }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@“cell”];
  if (!cell) {
  cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@“cell”];
  cell.backgroundColor = UIColor.clearColor;
  cell.textLabel.textColor = UIColor.whiteColor;
  cell.detailTextLabel.textColor = UIColor.lightGrayColor;
  UIView *bg = [[UIView alloc] init];
  bg.backgroundColor = [UIColor colorWithRed:0.3 green:0.2 blue:0.6 alpha:0.4];
  cell.selectedBackgroundView = bg;
  }
  NSDictionary *s = self.scripts[indexPath.row];
  cell.textLabel.text = s[@“title”];
  cell.detailTextLabel.text = [NSString stringWithFormat:@“By %@  •  %@”, s[@“author”], s[@“game”]];
  return cell;
  }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  NSDictionary *s = self.scripts[indexPath.row];
  [self.spinner startAnimating];
  [SRFXScriptBlox fetchScript:s[@“slug”] completion:^(NSString *code) {
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
  if (searchBar.text.length == 0) {
  [self loadTrendingScripts];
  return;
  }
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
- (void)handlePrint:(NSNotification *)note {
  dispatch_async(dispatch_get_main_queue(), ^{
  [self.consoleText appendFormat:@”%@\n”, note.object];
  self.consoleView.text = self.consoleText;
  });
  }
- (void)handleError:(NSNotification *)note {
  dispatch_async(dispatch_get_main_queue(), ^{
  [self.consoleText appendFormat:@”[ERROR] %@\n”, note.object];
  self.consoleView.text = self.consoleText;
  });
  }
- (void)execute {
  if (self.editor.text.length > 0)
  SRFXLuaExecute(self.editor.text.UTF8String);
  }
- (void)clear {
  self.editor.text = @””;
  self.consoleText = [NSMutableString string];
  self.consoleView.text = @””;
  }
- (void)hide { self.view.window.hidden = YES; }
- (void)minimize { self.view.window.hidden = YES; }
- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  }

@end
