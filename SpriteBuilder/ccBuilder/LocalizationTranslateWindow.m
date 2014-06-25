//
//  LocalizationTranslateWindow.m
//  SpriteBuilder
//
//  Created by Benjamin Koatz on 6/4/14.
//
//

#import "LocalizationTranslateWindow.h"
#import "LocalizationEditorHandler.h"
#import "AppDelegate.h"
#import "LocalizationEditorLanguage.h"
#import "LocalizationEditorTranslation.h"
#import "LocalizationEditorWindow.h"
#import "LocalizationTranslateWindowHandler.h"

@implementation LocalizationTranslateWindow

@synthesize parentWindow = _parentWindow;

#pragma mark Standards for the tab view
static int downloadLangsIndex = 0;
static int noActiveLangsIndex = 1;
static int standardLangsIndex = 2;
static int downloadCostErrorIndex = 3;
static int downloadLangsErrorIndex = 4;

#pragma mark URLs
static NSString* languageURL = @"http://spritebuilder-meteor.herokuapp.com/api/v1/translations/languages?key=%@";
static NSString* const estimateURL = @"http://spritebuilder-meteor.herokuapp.com/api/v1/translations/estimate";
static NSString* const receiptURL = @"http://spritebuilder-rails.herokuapp.com/translations";
static NSString* translationsURL = @"http://spritebuilder-rails.herokuapp.com/translations?key=%@";

#pragma mark Messages for the user
static NSString* const noActiveLangsString = @"No Valid Languages";
static NSString* const downloadingLangsString = @"Downloading...";
static NSString* missingActiveLangsErrorString = @"Additional translatable language(s): %@.\r\rTo activate, select \"Add Language\" in Language Translation window and add phrases you want to translate.";
static NSString* noActiveLangsErrorString = @"We support translations from:\r\r%@.";

#pragma mark Init

/*
 * Set up the guid, the languages global dictionary, the tab views, the window handler
 * and get the dictionary's contents from the server
 */
-(void) awakeFromNib
{
    _guid = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] objectForKey:@"sbUserID"];
    _languages = [[NSMutableDictionary alloc] init];
    [[_translateFromTabView tabViewItemAtIndex:downloadLangsIndex] setView:_downloadingLangsView];
    [[_translateFromTabView tabViewItemAtIndex:noActiveLangsIndex] setView:_noActiveLangsView];
    [[_translateFromTabView tabViewItemAtIndex:standardLangsIndex] setView:_standardLangsView];
    [[_translateFromTabView tabViewItemAtIndex:downloadCostErrorIndex] setView:_downloadingCostsErrorView];
    [[_translateFromTabView tabViewItemAtIndex:downloadLangsErrorIndex] setView:_downloadingLangsErrorView];
    [((LocalizationTranslateWindowHandler*)self.window) setPopOver:_translatePopOver button:_translateFromInfo];
    [self disableAll];
    [self getLanguagesFromServer];
    
}

#pragma mark Downloading and updating languages

/*
 * Disable the translate from menu and show the downloading languages message.
 * Get languages from server and update active langauges. Once the session 
 * is done the JSON data will be parsed if there wasn't an error.
 */
-(void)getLanguagesFromServer{
    _popTranslateFrom.title = downloadingLangsString;
    [_translateFromTabView selectTabViewItemAtIndex:downloadLangsIndex];
    [_languagesDownloading startAnimation:self];
    NSString* URLstring =
    [NSString stringWithFormat:languageURL, _guid];
    NSURL* url = [NSURL URLWithString:URLstring];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL: url
                                                             completionHandler:^(NSData *data,
                                                                                 NSURLResponse *response,
                                                                                 NSError *error)
                                  {
                                      if (!error)
                                      {
                                          [self parseJSONLanguages:data];
                                          NSLog(@"Status code: %li", ((NSHTTPURLResponse *)response).statusCode);
                                      }
                                      else
                                      {
                                          NSLog(@"Error: %@", error.localizedDescription);
                                      }
                                  }];
    [task resume];
}

-(void)disableAll{
    [_popTranslateFrom setEnabled:0];
    [_languageTable setEnabled:0];
    [_checkAll setEnabled:0];
    [_ignoreText setEnabled:0];
    [_cancel setEnabled:0];
}

-(void)enableAll{
    [_popTranslateFrom setEnabled:1];
    [_languageTable setEnabled:1];
    [_checkAll setEnabled:1];
    [_ignoreText setEnabled:1];
    [_cancel setEnabled:1];
}
/*
 * Turns the JSON response into a dictionary and fill the _languages global accordingly.
 * Then update the active languages array, the pop-up menu and the table. This is
 * only done once in the beginning of the SpriteBuilder session. Errors handled and 
 * displayed.
 */
-(void)parseJSONLanguages:(NSData *)data{
    NSError *JSONerror;
    NSMutableDictionary* availableLanguagesDict = [NSJSONSerialization JSONObjectWithData:data
                                                                                  options:NSJSONReadingMutableContainers error:&JSONerror];
    if(JSONerror || [[[availableLanguagesDict allKeys] firstObject] isEqualToString:@"Error"])
    {
        NSLog(@"%@", JSONerror ? [NSString stringWithFormat:@"JSONError: %@", JSONerror.localizedDescription] :
              [NSString stringWithFormat:@"Error: %@", [availableLanguagesDict objectForKey:@"Error"]]);
        [_languagesDownloading stopAnimation:self];
        [_translateFromTabView selectTabViewItemAtIndex:downloadLangsErrorIndex];
        return;
    }
    for(NSString* lIso in availableLanguagesDict.allKeys)
    {
        NSMutableArray* translateTo = [[NSMutableArray alloc] init];
        for(NSString* translateToIso in (NSArray *)[availableLanguagesDict objectForKey:lIso])
        {
            [translateTo addObject:[[LocalizationEditorLanguage alloc] initWithIsoLangCode:translateToIso]];
        }
        [_languages setObject:translateTo forKey:[[LocalizationEditorLanguage alloc] initWithIsoLangCode:lIso]];
    }
    [self updateActiveLanguages];
    [self finishSetUp];
}

/*
 * Remove active languages not in the keys of the global languages dictionary
 */
-(void)updateActiveLanguages{
    LocalizationEditorHandler* handler = [AppDelegate appDelegate].localizationEditorHandler;
    _activeLanguages = [[NSMutableArray alloc] initWithArray:handler.activeLanguages];
    NSMutableArray* activeLangsCopy = _activeLanguages.copy;
    for(LocalizationEditorLanguage* l in activeLangsCopy)
    {
        if(![[_languages allKeys] containsObject:l])
        {
            [_activeLanguages removeObject:l];
        }
    }
}

/*
 * Once the languages are retrieved, this is called. The spinning wheel and 
 * message indicating downloading languages are hidden. All languages' quickEdit
 * settings are checked off, and if there are active languages, the pop-up
 * 'translate from' menu is set up and, in that function, the language table's
 * data is reloaded.
 * If there are no active languages that we can translate from
 * then a the pop-up menu is disabled, an error message with instructions is shown.
 */
-(void)finishSetUp{
    
    [_languagesDownloading stopAnimation:self];
    [self uncheckLanguageDict];
    if(_activeLanguages.count)
    {
        LocalizationEditorLanguage* l = [_activeLanguages objectAtIndex:0];
        _currLang = l;
        _popTranslateFrom.title = l.name;
        [self enableAll];
        [_translateFromTabView selectTabViewItemAtIndex:standardLangsIndex];
        [self updateLanguageSelectionMenu:0];
    }
    else
    {
        _currLang = NULL;
        _popTranslateFrom.title = noActiveLangsString;
        [self updateNoActiveLangsError];
        [_translateFromTabView selectTabViewItemAtIndex:noActiveLangsIndex];
    }
}

/*
 * Turns off the 'quick edit' option in the languages global dictionary
 * e.g. 'unchecks' them
 */
-(void)uncheckLanguageDict{
    for(LocalizationEditorLanguage* l in [_languages allKeys])
    {
        l.quickEdit = 0;
        for(LocalizationEditorLanguage* l2 in [_languages objectForKey:l])
            l2.quickEdit = 0;
    }
}

/*
 * If this is coming out of an instance where the language selection menu has to be 
 * updated without a user selection (the initial post-download call or reload after 
 * a language is added/deleted on the Language Translation window) everything is normal. But
 * if this is just a normal user selection, and the user reselected the current language, 
 * ignore this and return.
 *
 * Otherwise, remove all items from the menu, then put all the active langauges back into it.
 * Set the global currLang to the newly selected language and if this isn't the initial
 * update (e.g. if the window is already loaded and someone is selecting a new language
 * to translate from) then update the main language table and the check all box accordingly.
 * Finally, toggle the visibility of the 'Translate From Info' button.
 *
 * The 'isNewLangActive' variable handles the edge case where a user deletes an active
 * 'translate from' language from the Langauge window, and just sets the current language
 * and language selection menu accordingly.
 */
- (void) updateLanguageSelectionMenu:(NSInteger)userReselection
{
    NSString* newLangSelection = _popTranslateFrom.selectedItem.title;
    if(self.isWindowLoaded && _currLang && userReselection && [newLangSelection isEqualToString:_currLang.name])
    {
        return;
    }
    if(!_currLang)
    {
        newLangSelection = ((LocalizationEditorLanguage*)[_activeLanguages objectAtIndex:0]).name;
    }
    
    [_popTranslateFrom removeAllItems];
    NSMutableArray* langTitles = [NSMutableArray array];
    int isNewLangActive = 0;
    for (LocalizationEditorLanguage* lang in _activeLanguages)
    {
        if([lang.name isEqualToString:newLangSelection])
        {
            isNewLangActive = 1;
            _currLang = lang;
        }
        [langTitles addObject:lang.name];
    }
    [_popTranslateFrom addItemsWithTitles:langTitles];
    
    if(!isNewLangActive){
        _currLang = [_activeLanguages objectAtIndex:0];
        [_popTranslateFrom selectItemWithTitle:_currLang.name];
    }
    else if (newLangSelection)
    {
        [_popTranslateFrom selectItemWithTitle:newLangSelection];
    }
    if([self isWindowLoaded])
    {
        [_languageTable reloadData];
        [self updateCheckAll];
    }
    [self toggleTranslateFromInfo];
    
}

/*
 * Toggles whether or not you can see the 'Translate From Info' button
 * depending on if there are languages that can still be activated.
 */
-(void)toggleTranslateFromInfo{
    if(_activeLanguages.count == [_languages allKeys].count)
    {
        if(_translatePopOver.isShown)
        {
            [_translatePopOver close];
        }
        [_translateFromInfo setHidden:1];
    }
    /*else
    {
        [_translateFromInfo setHidden:0];
    }*/
}

#pragma mark Downloading Cost Estimate and word count

/*
 * Gets the estimated cost of a translation request using the currrent user-set parameters.
 * Updates phrases to translate, returning the number of phrases the user is asking to
 * translate. Set both the number of words and the cost to 0 if there are 0 phrases to
 * translate.
 *
 * We then start the spinning download image and a download message, and send the array of 
 * phrases as a post request to the the 'estimate' spritebuilder URL, and receive the number 
 * of the appropriate Apple Price Tier and the number of words that are in the the phrase we
 * want to translate. We then send that price tier to Apple to come up with the appropriate, 
 * localized price.
 */
-(void)getCostEstimate{
    
    NSInteger phrases = [self updatePhrasesToTranslate];
    if(phrases == 0)
    {
        _cost.stringValue = _numWords.stringValue = @"0";
        [_buy setEnabled:0];
        return;
    }
    [_translateFromTabView selectTabViewItemAtIndex:standardLangsIndex];
    [_costDownloading setHidden:0];
    [_costDownloadingText setHidden:0];
    [_costDownloading startAnimation:self];
     NSDictionary *JSONObject = [[NSDictionary alloc] initWithObjectsAndKeys:
                                 _guid,@"key",
                                 _phrasesToTranslate,@"phrases",
                                 nil];
    if(![NSJSONSerialization isValidJSONObject:JSONObject]){
        NSLog(@"Not a JSON Object!!!");
    }
     NSError *error;
     NSData *postdata = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error];
    if(error){
        NSLog(@"Error: %@", error);
    }
     NSURL *url = [NSURL URLWithString:estimateURL];
     NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
     request.HTTPMethod = @"POST";
     request.HTTPBody = postdata;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
     NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest: request
                                                                  completionHandler:^(NSData *data,
                                                                                      NSURLResponse *response,
                                                                                      NSError *error)
    {
                    if (!error)
                    {
                        [self parseJSONEstimate:data];
                        if(_tierForTranslations > 0)
                        {
                            [self requestIAPProducts];
                        }
                        NSLog(@"Status code: %li", ((NSHTTPURLResponse *)response).statusCode);
                    }
                    else
                    {
                        NSLog(@"Error: %@", error.localizedDescription);
                    }
     }];
     [task resume];
}

/*
 * Goes through every LocalizationEditorTranslation, first seeing if there is a
 * version of the phrase in the 'translate from' language.
 * Then populating an array of the isoCodes for every language the phrase should be
 * translated to. (If we are ignoring already translated text, this is every language
 * with 'quick edit' enable. If we aren't, this is only those translations that don't
 * have a translation string already.)
 * If that array remains unpopulated, then we ignore this translation. We then add this
 * number to the number of tranlsations to download (for the progress bar later). Then
 * we create a dictionary of the 'translate from' text, the context (if it exists), the
 * source language, the languages to translate to and add that dictionary to an array
 * of phrases.
 *
 * Return the number of phrases to translate.
 */
-(NSInteger)updatePhrasesToTranslate{
    LocalizationEditorHandler* handler = [AppDelegate appDelegate].localizationEditorHandler;
    NSMutableArray* trans = handler.translations;
    _phrasesToTranslate = [[NSMutableArray alloc] init];
    for(LocalizationEditorTranslation* t in trans)
    {
        NSString* toTranslate = [t.translations objectForKey:_currLang.isoLangCode];
        if(!toTranslate || [toTranslate isEqualToString:@""])
        {
            continue;
        }
        NSMutableArray* langsToTranslate = [[NSMutableArray alloc] init];
        for(LocalizationEditorLanguage* l in [_languages objectForKey:_currLang])
        {
            NSString* tempTrans = [t.translations objectForKey:l.isoLangCode];
            if((!tempTrans  || [tempTrans isEqualToString:@""]) || !_ignoreText.state)
            {
                if(l.quickEdit)
                {
                    [langsToTranslate addObject:l.isoLangCode];
                }
            }
        }
        if(!langsToTranslate.count)
        {
            continue;
        }
        _numTransToDownload += langsToTranslate.count;
        NSDictionary *phrase;
        if(t.comment && ![t.comment isEqualToString:@""])
        {
            phrase = [[NSDictionary alloc] initWithObjectsAndKeys:
                      t.key, @"key",
                      [t.translations objectForKey:_currLang.isoLangCode], @"text",
                      t.comment, @"context",
                      _currLang.isoLangCode,@"source_language",
                      langsToTranslate,@"target_languages",
                      nil];
        }
        else
        {
            phrase = [[NSDictionary alloc] initWithObjectsAndKeys:
                      t.key, @"key",
                      [t.translations objectForKey:_currLang.isoLangCode], @"text",
                      _currLang.isoLangCode,@"source_language",
                      langsToTranslate,@"target_languages",
                      nil];
        }
        [_phrasesToTranslate addObject:phrase];
    }
    return _phrasesToTranslate.count;
}

/*
 * Parses the JSON response from a request for a cost estimate. Handles error and sets
 * the translation tier and number of words.
 */
-(void)parseJSONEstimate:(NSData*)data{
    NSError *JSONerror;
    NSDictionary* dataDict  = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&JSONerror];
    if(JSONerror || [[[dataDict allKeys] firstObject] isEqualToString:@"Error"])
    {
        NSLog(@"%@", JSONerror ? [NSString stringWithFormat:@"JSONError: %@", JSONerror.localizedDescription] :
              [NSString stringWithFormat:@"Error: %@", [dataDict objectForKey:@"Error"]]);
        [_costDownloading stopAnimation:self];
        [_translateFromTabView selectTabViewItemAtIndex:downloadCostErrorIndex];
        return;
    }
    _tierForTranslations  = [[dataDict objectForKey:@"iap_price_tier"] intValue];
    _numWords.stringValue = [[dataDict objectForKey:@"wordcount"] stringValue];
}

/*
 * Get the IAP PIDs from the correct plist, put those into a Products Request and start that request.
 */
-(void)requestIAPProducts{
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"LocalizationInAppPurchasesPIDs" withExtension:@".plist"];
    NSArray *productIdentifiers = [NSArray arrayWithContentsOfURL:url];
    NSSet* identifierSet = [NSSet setWithArray:productIdentifiers];
    SKProductsRequest* request = [[SKProductsRequest alloc] initWithProductIdentifiers:identifierSet];
    [request setDelegate:self];
    [request start];
}

#pragma mark Toggling/Clicking button events

/*
 * Solicit a payment and set the cancel button to say 'Finish'.
 */
- (IBAction)buy:(id)sender {
    if(!_products.count || !_phrasesToTranslate.count)
        return;
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    SKPayment* payment = [SKPayment paymentWithProduct:[_products objectAtIndex:(_tierForTranslations -1)]];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

/*
 * Close the window.
 */
- (IBAction)cancel:(id)sender {
    [NSApp endSheet:self.window];
    [self.window close];
}

/*
 * If a user clicks or unclicks ignore then update the cost of the translations
 * they are seeking.
 */
- (IBAction)toggleIgnore:(id)sender {
    [self getCostEstimate];
}

/*
 * Update the langauge select menu if someone has selected the pop-up
 * 'translate from' menu. Send 0 because this is not a reload, it is a
 * user-click generated event.
 */
- (IBAction)selectedTranslateFromMenu:(id)sender {
    [self updateLanguageSelectionMenu:1];
}

/*
 * If the check all box has been clicked, turn off mixed state (so
 * people can only go from no check to check) and update the quickEdit
 * state of all languages in the array of 'translate to' langauges for 
 * the current language and reload the main language table.
 */
- (IBAction)toggleCheckAll:(id)sender {
    _checkAll.allowsMixedState = 0;
    for (LocalizationEditorLanguage* l in [_languages objectForKey:_currLang])
        l.quickEdit = _checkAll.state;
    [_languageTable reloadData];
}

/*
 * Toggles the 'translate from' info popover according to when you click on the
 * info button
 */
- (IBAction)showInfo:(id)sender {
    [self updateMissingActiveLangs];
    if(_translateFromInfo.intValue == 1){
        [_translatePopOver showRelativeToRect:[_translateFromInfo bounds] ofView:_translateFromInfo preferredEdge:NSMaxYEdge];
    }else{
        [_translatePopOver close];
    }
}

/*
 * Clicked if there was an error in downloading languages and the user
 * wants to retry
 */
- (IBAction)retryLanguages:(id)sender {
    [self getLanguagesFromServer];
}

/*
 * Clicked if there was an error in downloading cost Estimate and the user
 * wants to retry
 */
- (IBAction)retryCost:(id)sender {
    [self getCostEstimate];
}

#pragma mark Response to events in the main Language Window

/*
 * Once a new language is input to the Language Translate window's main
 * table, this is called to reload the cost in the translate window.
 */
- (void)reloadCost{
    [self getCostEstimate];
}

/*
 * Update the active languages from the Language Translate window. If this
 * event is being percolated by a no active languages message, flash that 
 * message if the problem has not been fixed (e.g. they added a language 
 * that isn't in the keys of the language dictionary) or hide the message
 * and enable and update the menu. 
 *
 * If this is being called because of a missing languages message, hide that 
 * message if all possible active langauges are activated and then update 
 * the language menu. If the user has deleted all active languages, 
 * turn the tab view into a no active languages error.
 */
- (void)reloadLanguageMenu{
    [self updateActiveLanguages];
    if([_translateFromTabView indexOfTabViewItem:[_translateFromTabView selectedTabViewItem]]
       == noActiveLangsIndex)
    {
        if(!_activeLanguages.count)
        {
            NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(toggleNoActiveLangsAlpha) userInfo:nil repeats:NO];
            timer = [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(toggleNoActiveLangsAlpha) userInfo:nil repeats:NO];
        }
        else
        {
            [_translateFromTabView selectTabViewItemAtIndex:standardLangsIndex];
            [_popTranslateFrom setEnabled:1];
            [self updateLanguageSelectionMenu: 0];
        }
    }else{
        if(!_activeLanguages.count)
        {
            [self updateNoActiveLangsError];
            [_translateFromTabView selectTabViewItemAtIndex:noActiveLangsIndex];
            [_translateFromInfo setHidden:1];
            [_popTranslateFrom setEnabled:0];
            _popTranslateFrom.title = noActiveLangsString;
            _currLang = NULL;
            [_languageTable reloadData];
        }else{
            [self updateMissingActiveLangs];
            [self updateLanguageSelectionMenu: 0];
        }
    }
}

/*
 * Flashes the no active langauges error.
 */
- (void)toggleNoActiveLangsAlpha {
    [_noActiveLangsError setHidden:(!_noActiveLangsError.isHidden)];
}

#pragma mark update error strings and the 'check all' button

/*
 * Put all the available but not inputted 'translate from' languages 
 * in the missing active langs message
 */
-(void)updateMissingActiveLangs{
    
    NSMutableString* s = [[NSMutableString alloc] initWithString:@""];
    for(LocalizationEditorLanguage* l in [_languages allKeys])
    {
        if(![_activeLanguages containsObject:l])
        {
            if(![s isEqualToString:@""])
            {
                [s appendString:@", "];
            }
            [s appendString:l.name];
        }
    }
    NSString* info = [NSString stringWithFormat: missingActiveLangsErrorString, s];
    
    _translateFromInfoV.string = info;
}

/*
 * Put all the available 'translate from' languages in the no active languages error
 */
-(void)updateNoActiveLangsError{
    
    NSMutableString* s = [[NSMutableString alloc] initWithString:@""];
    for(LocalizationEditorLanguage* l in [_languages allKeys])
    {
        if(![s isEqualToString:@""])
        {
            [s appendString:@"\r\r"];
        }
        [s appendString:l.name];
    }
    _noActiveLangsError.stringValue = [NSString stringWithFormat:noActiveLangsErrorString, s];
}

/*
 * Go through the dictionary of 'translate to' languages for the current language
 * and update the check all box accordingly
 */
-(void)updateCheckAll{
    BOOL checkAllFalse = 0;
    BOOL checkAllTrue = 1;
    for(LocalizationEditorLanguage* l in [_languages objectForKey:_currLang])
    {
        if(!l.quickEdit)
            checkAllTrue = 0;
        else
            checkAllFalse = 1;
    }
    if(checkAllFalse && !checkAllTrue)
    {
        _checkAll.allowsMixedState = 1;
        _checkAll.state = -1;
    }
    else if(!checkAllFalse)
    {
        _checkAll.allowsMixedState = 0;
        _checkAll.state = 0;
    }
    else
    {
        _checkAll.allowsMixedState = 0;
        _checkAll.state = 1;
    }
}

#pragma mark table view delegate

/*
 * If there's no current language then there's going to be nothing to
 * put in the tableView, so just return 0 for the size. Else, get the 
 * cost with the updated parameters and return the count of the array
 * of 'translate to' languages associate with the current language.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    
    if(!_currLang)
    {
        return 0;
    }
    [self getCostEstimate];
    return ((NSArray*)[_languages objectForKey:_currLang]).count;
}

/*
 * If there's no current language then there's going to be nothing to put in the tableView, 
 * so just return 0. Else, just return the values for stuff from the 'translate from' array 
 * for the current language.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if(!_currLang)
    {
     return 0;
    }
   if ([aTableColumn.identifier isEqualToString:@"enabled"])
    {
        LocalizationEditorLanguage* lang = [((NSArray*)[_languages objectForKey:_currLang]) objectAtIndex:rowIndex];
        return [NSNumber numberWithBool:lang.quickEdit];
    }
    else if ([aTableColumn.identifier isEqualToString:@"name"])
    {
        LocalizationEditorLanguage* lang = [((NSArray*)[_languages objectForKey:_currLang]) objectAtIndex:rowIndex];
        return lang.name;
    }
    return NULL;
}

/*
 * Update the check all box and get new cost when the user toggles one of the languages in the main language table.
 */
- (void) tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([tableColumn.identifier isEqualToString:@"enabled"])
    {
        LocalizationEditorLanguage* lang = [((NSArray*)[_languages objectForKey:_currLang]) objectAtIndex:row];
        lang.quickEdit = [object boolValue];
        [self updateCheckAll];
        [self getCostEstimate];
    }
}

#pragma mark request delegate (and price display)

-(void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    NSLog(@"Request failed");
}
-(void)requestDidFinish:(SKRequest *)request{
    NSLog(@"Request finished");
}
/*
 * Takes in the products returned by apple, prints any invalid identifiers and displays
 * the price of those products.
 */
-(void) productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    NSLog(@"Product Request");
    _products = response.products;
    for(NSString *invalidIdentifier in response.invalidProductIdentifiers)
    {
        [_translateFromTabView selectTabViewItemAtIndex:downloadCostErrorIndex];
        [_costDownloading stopAnimation:self];
        NSLog(@"Invalid Identifier: %@",invalidIdentifier);
        return;
    }
    [self displayPrice];
}

/*
 * Locally format the price of the current translation estimate, display it,
 * and hide the cost downloading message and spinning icon.
 */
-(void)displayPrice{
    SKProduct* p = [_products objectAtIndex:(_tierForTranslations - 1)];
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:p.priceLocale];
    NSString *formattedString = [numberFormatter stringFromNumber:p.price];
    _cost.stringValue = formattedString;
    [_costDownloading setHidden:1];
    [_costDownloadingText setHidden:1];
    [_costDownloading stopAnimation:self];
    [_buy setEnabled:1];
}

#pragma mark payment transaction observer

/*
 * Ask for a receipt for any updated paymnent transactions.
 */
-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions{
    NSURL* receiptURL;
    for (SKPaymentTransaction* transaction in transactions)
    {
        switch(transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                NSData* receipt = [NSData dataWithContentsOfURL:receiptURL];
                [_receipts setObject:receipt forKey:transaction.transactionIdentifier];
                [self validateReceipt:[[NSString alloc] initWithData:receipt encoding:NSASCIIStringEncoding]];
                break;
        }
    }
}

/*
 * Validates the receipt with our server.
 * TODO check for translations!
 */
-(void)validateReceipt:(NSString *)receipt{
    NSDictionary *JSONObject = [[NSDictionary alloc] initWithObjectsAndKeys: _guid,@"key",receipt,@"receipt",_phrasesToTranslate,@"phrases",nil];
    NSError *error;
    if(![NSJSONSerialization isValidJSONObject:JSONObject]){
        NSLog(@"Invalid JSON");
        return;
    }
    NSData *postdata2 = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error];
    NSURL *url = [NSURL URLWithString:receiptURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = postdata2;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest: request
                                                             completionHandler:^(NSData *data,
                                                                                 NSURLResponse *response,
                                                                                 NSError *error)
                                  {
                                      if (!error)
                                      {
                                          [self setLanguageWindowDownloading];
                                          [self parseJSONTranslations:data];
                                          _timerTransDownload = [NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector(getTranslations) userInfo:nil repeats:YES];
                                          NSLog(@"Status code: %li", ((NSHTTPURLResponse *)response).statusCode);
                                      }
                                      else
                                      {
                                          NSLog(@"Error: %@", error.localizedDescription);
                                      }
                                  }];
    [task resume];
}

-(void)setLanguageWindowDownloading{
    LocalizationEditorHandler* handler = [AppDelegate appDelegate].localizationEditorHandler;
    NSArray* translations = handler.translations;
    for(LocalizationEditorTranslation* t in translations)
    {
        for(NSDictionary* d in _phrasesToTranslate)
        {
            if([t.key isEqualToString:[d objectForKey:@"key"]])
            {
                t.languagesDownloading = [d objectForKey:@"target_languages"];
                [_parentWindow addLanguages:[d objectForKey:@"target_languages"]];
                break;
            }
        }
    }
    [_parentWindow setDownloadingTranslations:_numTransToDownload];
}
/*
 * Turns the JSON response into a dictionary and fill the _languages global accordingly.
 * Then update the active languages array, the pop-up menu and the table. This is
 * only done once in the beginning of the SpriteBuilder session.
 */
-(void)parseJSONTranslations:(NSData *)data{
    NSError *JSONerror;
    NSDictionary* initialTransDict  = [NSJSONSerialization JSONObjectWithData:data
                                                                                  options:NSJSONReadingMutableContainers error:&JSONerror];
    if(JSONerror)
    {
        NSLog(@"JSONError: %@", JSONerror.localizedDescription);
        return;
    }
    LocalizationEditorHandler* handler = [AppDelegate appDelegate].localizationEditorHandler;
    NSArray* handlerTranslations = handler.translations;
    NSArray* initialTrans = [initialTransDict objectForKey:@"phrases"];
    for(NSDictionary* transForKeys in initialTrans)
    {
        NSString* keyToTranslate = [transForKeys.allKeys objectAtIndex:0];
        NSDictionary* transDict = [transForKeys objectForKey:keyToTranslate];
        for(NSString* lang in transDict.allKeys){
            NSString* translation = [transDict objectForKey:lang];
            for(LocalizationEditorTranslation* t in handlerTranslations)
            {
                if([t.key isEqualToString:keyToTranslate] && [t.languagesDownloading containsObject:lang]){
                    [t.translations setObject:translation forKey:lang];
                    [t.languagesDownloading removeObject:lang];
                    [_parentWindow incrementTransByOne];
                }
            }
        }
    }
    if([_parentWindow translationProgress] == _numTransToDownload){
        [_parentWindow finishDownloadingTranslations];
    }
}

-(void)getTranslations{
    NSString* URLstring =
    [NSString stringWithFormat:translationsURL, _guid];
    NSURL* url = [NSURL URLWithString:URLstring];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL: url
                                                             completionHandler:^(NSData *data,
                                                                                 NSURLResponse *response,
                                                                                 NSError *error)
                                  {
                                      if (!error)
                                      {
                                          
                                          [self parseJSONTranslations:data];
                                          NSLog(@"Status code: %li", ((NSHTTPURLResponse *)response).statusCode);
                                      }
                                      else
                                      {
                                          NSLog(@"Error: %@", error.localizedDescription);
                                      }
                                  }];
    [task resume];
    
}
@end
