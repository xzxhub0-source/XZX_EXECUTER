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

- (void)minimize {
    self.view.window.hidden = YES;
}
