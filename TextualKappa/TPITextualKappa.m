//
//  TPITextualKappa.m
//  TextualKappa
//
//  Created by Sara on 11/3/15.
//  Copyright © 2015 sbine. All rights reserved.
//

#import "TPITextualKappa.h"

#define TWITCH_IRC_SERVER @"irc.chat.twitch.tv"

@interface TPITextualKappa ()

@property (strong) IBOutlet NSView *preferenceView;
@property (strong) IBOutlet NSArrayController *serversArrayController;
@property (strong) IBOutlet NSTableView *serversTable;
@property (strong) NSMutableArray *observedClients;

- (NSView *)pluginPreferencesPaneView;
- (NSString *)pluginPreferencesPaneMenuItemName;

- (IBAction)preferenceChanged:(id)sender;
- (IBAction)onAddServer:(id)sender;

@end

@implementation TPITextualKappa

#pragma mark -
#pragma mark Plugin API Hooks

- (void)pluginLoadedIntoMemory
{
    [self performBlockOnMainThread:^{
        NSDictionary *defaultPreferences = @{
            @"TPITextualKappaPlugin": @(YES),
            @"TPITextualKappaTwitch": @(YES),
            @"TPITextualKappaBetterTTV": @(YES),
        };
        [RZUserDefaults() registerDefaults:defaultPreferences];

        [TPIBundleFromClass() loadNibNamed:@"TPITextualKappaPrefs" owner:self topLevelObjects:nil];
    }];

    if ([RZUserDefaults() boolForKey:@"TPITextualKappaPlugin"]) {
        [RZNotificationCenter() addObserver:self
                                   selector:@selector(logControllerViewFinishedLoading:)
                                       name:TVCLogControllerViewFinishedLoadingNotification
                                     object:nil];

        [RZNotificationCenter() addObserver:self
                                   selector:@selector(addClientObservers)
                                       name:IRCWorldClientListWasModifiedNotification
                                     object:nil];

        [self addClientObservers];
    }
}

- (void)pluginWillBeUnloadedFromMemory
{
    [RZNotificationCenter() removeObserver:self];
}

- (IRCMessage *)interceptServerInput:(IRCMessage *)input for:(IRCClient *)client
{
    // Capture PRIVMSGs
    if ([[input command] isEqualToString:@"PRIVMSG"]) {

        // Check for the presence of IRCv3 message tags
        if ([[input messageTags] count] > 0) {
            return [self interceptPrivmsgsKappaAddon:[input mutableCopy] senderInfo:[[input sender] mutableCopy] client:client];
        }
    }

    // Capture USERSTATE
    if ([[input command] isEqualToString:@"USERSTATE"]) {
        NSDictionary *messageTags = [input messageTags];

        // Twitch sends username capitalization preferences in the "display-name" key
        // Pass this information to JavaScript to replace when rendering
        if ((messageTags[@"display-name"] != nil)) {
            TVCLogView *webView = mainWindow().selectedItem.viewController.backingView;

            NSString *code = [NSString stringWithFormat:@"TextualKappa.updateDisplayName('%@');", messageTags[@"display-name"]];

            [webView evaluateJavaScript:code];
        }
    }

    return input;
}

#pragma mark -
#pragma mark Twitch PRIVMSG Parsing

- (IRCMessage *)interceptPrivmsgsKappaAddon:(IRCMessageMutable *)input senderInfo:(IRCPrefixMutable *)senderInfo client:(IRCClient *)client
{
    // Make a mutable copy of message parameters to modify & return
    NSMutableArray *mutableParams = [[input params] mutableCopy];
    NSDictionary *messageTags = [input messageTags];

    // Check again for the presence of IRCv3 message tags, for science
    if ([messageTags count] > 0) {

        NSString *nickname = senderInfo.nickname;

        // Twitch sends username capitalization preferences in the "display-name" key
        if ((messageTags[@"display-name"] != nil)) {

            // Ignore empty strings as Twitch sends them for users who have since been kicked from a channel
            if ([messageTags[@"display-name"] length] != 0) {
                nickname = messageTags[@"display-name"];
            }

        }

        // Does this user have badges assigned?
        if (messageTags[@"badges"] != nil) {
            nickname = [self addBadgesToNickname:nickname withBadges:messageTags[@"badges"]];
        }

        /*
         * Commented out 12/14/16
         * Twitch now passes turbo/subscriber/moderator as part of the "badges" property
         * This method of determining status will likely be phased out

        // Is this user a subscriber to the current broadcast?
        if ((messageTags[@"subscriber"] != nil) && ([messageTags[@"subscriber"] integerValue] == 1)) {

            nickname = [NSString stringWithFormat:@"💎%@", nickname];

        }

        // Is this user a Twitch Turbo member?
        if ((messageTags[@"turbo"] != nil) && ([messageTags[@"turbo"] integerValue] == 1)) {

            nickname = [NSString stringWithFormat:@"⚡%@", nickname];

        }
         */

        // Is this user a moderator or Twitch staff?
        if ((messageTags[@"user-type"] != nil)) {

            // Use standard emoji as placeholders
            if ([messageTags[@"user-type"]  isEqual:@"mod"]) {
                // TODO: confirm that global_mod/staff/admin are also specified in "badges"
                // if so, remove this whole block
                //nickname = [NSString stringWithFormat:@"⚔%@", nickname];
            } else if ([messageTags[@"user-type"]  isEqual:@"global_mod"]) {
                nickname = [NSString stringWithFormat:@"🔨%@", nickname];
            } else if ([messageTags[@"user-type"]  isEqual:@"admin"]) {
                nickname = [NSString stringWithFormat:@"🔰%@", nickname];
            } else if ([messageTags[@"user-type"]  isEqual:@"staff"]) {
                nickname = [NSString stringWithFormat:@"🔧%@", nickname];
            }
            
        }

        // Emoticons!
        if ([RZUserDefaults() boolForKey:@"TPITextualKappaTwitch"]) {
            if ((messageTags[@"emotes"] != nil) && ([input params][1] != nil)) {

                NSString *messageString = [input params][1];
                NSDictionary *emoteDirectives = [self getEmoticonDirectivesFromString:messageString withEmoteIndices:messageTags[@"emotes"]];
                messageString = [self replaceEmoticonsInString:messageString withEmoteDirectives:emoteDirectives];

                mutableParams[1] = messageString;
            }
        }

        [senderInfo setNickname:nickname];
        [input setSender:senderInfo];
        [input setParams:mutableParams];
    }

    return input;
}

#pragma mark -
#pragma mark Resource Injection

- (void)logControllerViewFinishedLoading:(NSNotification *)notification
{

    [self performBlockOnMainThread:^{
        TVCLogController *controller = [notification object];

        if (controller != nil) {
            TVCLogView *logView = [controller backingView];
            WebView *webView = (WebView *)[logView webView];
            DOMDocument *document = [webView mainFrameDocument];
            DOMNode *head = [[document getElementsByTagName:@"head"] item:0];
            NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];

            NSString *cssPath = [mainBundle pathForResource:@"style" ofType:@"css" inDirectory:@"Resources"];
            NSString *jsPath = [mainBundle pathForResource:@"script" ofType:@"js" inDirectory:@"Resources"];
            NSString *jsPostLoadPath = [mainBundle pathForResource:@"script-postload" ofType:@"js" inDirectory:@"Resources"];

            DOMElement *cssInclude = [document createElement:@"link"];
            [cssInclude setAttribute:@"rel" value:@"stylesheet"];
            [cssInclude setAttribute:@"type" value:@"text/css"];
            [cssInclude setAttribute:@"href" value:cssPath];

            DOMElement *jsInclude = [document createElement:@"script"];
            [jsInclude setAttribute:@"type" value:@"application/ecmascript"];
            [jsInclude setAttribute:@"src" value:jsPath];

            // Inject plugin's CSS and JS into each view
            [head appendChild:cssInclude];
            [head appendChild:jsInclude];

            // Mark Twitch channels with a data attribute
            if ([self pluginIsEnabledForClient:[controller associatedClient]]) {
                DOMNode *bodyNode = [[document getElementsByTagName:@"body"] item:0];
                if ([bodyNode isKindOfClass:[DOMElement class]]) {
                    DOMElement *body = (DOMElement *) bodyNode;

                    [body setAttribute:@"data-twitch-channel" value:@"1"];

                    if ([RZUserDefaults() boolForKey:@"TPITextualKappaTwitch"]) {
                        [body setAttribute:@"data-twitch-enabled-twitch" value:@"1"];
                    }
                    if ([RZUserDefaults() boolForKey:@"TPITextualKappaBetterTTV"]) {
                        [body setAttribute:@"data-twitch-enabled-betterttv" value:@"1"];
                    }

                    DOMElement *scriptPostLoadInclude = [document createElement:@"script"];
                    [scriptPostLoadInclude setAttribute:@"type" value:@"application/ecmascript"];
                    [scriptPostLoadInclude setAttribute:@"src" value:jsPostLoadPath];

                    [body appendChild:scriptPostLoadInclude];
                }
            }
        }
    }];
}

#pragma mark -
#pragma mark Key/Value Observation

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Verify this observer is for the IRCClient 'isLoggedIn' property
    if ([object class] == [IRCClient class] && [keyPath isEqualToString:@"isLoggedIn"]) {
        IRCClient *client = object;

        // Check if we are connected to a twitch.tv server
        if ([self pluginIsEnabledForClient:client] && [client isConnected] == YES) {

            // Send Twitch vendor-specific CAP requests
            [object send:IRCPrivateCommandIndex("cap"), @"REQ", @"twitch.tv/tags", nil];
            [object send:IRCPrivateCommandIndex("cap"), @"REQ", @"twitch.tv/membership", nil];
            [object send:IRCPrivateCommandIndex("cap"), @"REQ", @"twitch.tv/commands", nil];
        }
    }
}

- (void)addClientObservers
{
    @synchronized(self.observedClients) {

        NSArray *clientList = [worldController() clientList];

        for (IRCClient *client in self.observedClients) {
            if ([clientList containsObject:client] == NO) {
                [client removeObserver:self forKeyPath:@"isLoggedIn"];
            }
        }

        if (self.observedClients == nil) {
            self.observedClients = [NSMutableArray array];
        }

        for (IRCClient *client in clientList) {

            // Only add observers for twitch.tv servers
            if ([self pluginIsEnabledForClient:client]) {
                if ([self.observedClients containsObject:client] == NO) {
                    [self.observedClients addObject:client];

                    // Add observers for each IRCClient's 'isLoggedIn' property
                    [client addObserver:self
                             forKeyPath:@"isLoggedIn"
                                options:NSKeyValueObservingOptionNew
                                context:NULL];
                }
            }
        }
    }
}

#pragma mark -
#pragma mark String Replacement

- (NSDictionary *)getEmoticonDirectivesFromString:(NSString *)string withEmoteIndices:(NSString *)emoteIndices
{
    // Sample emoticon strings:
    // "12576:0-11,13-24,26-37,39-50";
    // "28087:0-6/68856:8-14/88:16-23";
    // "69731:0-9,21-30,42-51,63-72,84-93,105-114,126-135,147-156,168-177,189-198,210-219,231-240,252-261,273-282,294-303,315-324/32438:11-19,32-40,53-61,74-82,95-103,116-124,137-145,158-166,179-187,200-208,221-229,242-250,263-271,284-292,305-313,326-334";

    NSArray *emoticonDirectiveArray = [NSArray new];
    NSMutableDictionary *emoticonRangeDictionary = [NSMutableDictionary new];
    NSInteger offset = 0;

    // Is this PRIVMSG an ACTION? If so, add 8 to all indices
    NSRange positionOfAction = [string rangeOfString:@"ACTION"];
    if (positionOfAction.location == 1) {
        offset = 8;
    }

    // Distinct emoticon directives are separated by "/"
    emoticonDirectiveArray = [emoteIndices componentsSeparatedByString:@"/"];

    // Iterate over each emoticon directive
    for (NSString *emoticonDirective in emoticonDirectiveArray) {

        // Find the colon so we can split on it: <emoticon_id>:<emoticon_range1>,<emoticon_range2>
        NSRange positionOfColon = [emoticonDirective rangeOfString:@":"];

        if (positionOfColon.location != NSNotFound) {
            // Retrieve emoticon ID and indices of its location in the message
            NSString *emoticonId = [emoticonDirective substringToIndex:positionOfColon.location];
            NSString *emoticonIndices = [emoticonDirective substringAfterIndex:positionOfColon.location];

            NSArray *emoticonData = [emoticonIndices componentsSeparatedByString:@","];

            for (NSString *emoticonRange in emoticonData) {
                NSRange positionOfDash = [emoticonRange rangeOfString:@"-"];

                if (positionOfDash.location != NSNotFound) {
                    NSInteger startIndex = [[emoticonRange substringToIndex:positionOfDash.location] integerValue] + offset;
                    NSInteger endIndex = [[emoticonRange substringAfterIndex:positionOfDash.location] integerValue] + offset;
                    NSString *rangeAsString = [NSString stringWithFormat:@"{%li, %li}", startIndex, (endIndex - startIndex) + 1];

                    // Store the emoticon ID keyed by a NSRange string representation of its location in the message
                    emoticonRangeDictionary[rangeAsString] = emoticonId;
                }
            }
        }
    }

    return emoticonRangeDictionary;
}

- (NSString *)replaceEmoticonsInString:(NSString *)messageString withEmoteDirectives:(NSDictionary *)emoteDirectives
{
    NSMutableString *replacedString = [messageString mutableCopy];

    // Sort the emoticon dictionary in descending index order so in-place replacements don't invalidate subsequent indices
    NSArray *keys = [emoteDirectives allKeys];
    NSArray *sortedKeys = [keys sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSRange first = NSRangeFromString(a);
        NSRange second = NSRangeFromString(b);

        NSComparisonResult result = NSOrderedSame;
        if (first.location > second.location) {
            result = NSOrderedAscending;
        } else if (first.location < second.location) {
            result = NSOrderedDescending;
        }
        return result;
    }];

    // Loop over emoticon index and perform in-place replacements
    for (NSString *emoticonIndex in sortedKeys) {
        NSString *emoticonId = emoteDirectives[emoticonIndex];

        // TODO: remove the need for placeholder :twitch_<emote>:
        replacedString = [[replacedString stringByReplacingCharactersInRange:NSRangeFromString(emoticonIndex) withString:[NSString stringWithFormat:@":twitch_%@:", emoticonId]] mutableCopy];
    }

    return replacedString;
}

- (NSString *)addBadgesToNickname:(NSString *)nickname withBadges:(NSString *)badges
{
    NSArray *badgeArray = [NSArray new];
    NSMutableString *mutableNickname = [nickname mutableCopy];

    // Distinct badges are separated by ","
    badgeArray = [badges componentsSeparatedByString:@","];

    // Iterate over each badge
    for (NSString *badge in badgeArray) {

        NSRange positionOfSlash = [badge rangeOfString:@"/"];

        if (positionOfSlash.location != NSNotFound) {
            // Badges are versioned with "/", e.g. "premium/1"
            NSArray *badgeVersion = [NSArray new];
            badgeVersion = [badge componentsSeparatedByString:@"/"];

            if ((badgeVersion[0] != nil) && (badgeVersion[1] != nil)) {
                NSString *badgeType = badgeVersion[0];

                if ([badgeType isEqualToString:@"premium"]) {
                    mutableNickname = [NSMutableString stringWithFormat:@"👑/%@/%@", badgeVersion[1], mutableNickname];
                }
                else if ([badgeType isEqualToString:@"turbo"]) {
                    mutableNickname = [NSMutableString stringWithFormat:@"⚡/%@/%@", badgeVersion[1], mutableNickname];
                }
                else if ([badgeType isEqualToString:@"subscriber"]) {
                    // We don't want global subscriber icons.
                    // Use the old placeholder format so JS will fetch channel-specific subscriber icons
                    mutableNickname = [NSMutableString stringWithFormat:@"💎%@", mutableNickname];
                }
                else if ([badgeType isEqualToString:@"moderator"]) {
                    mutableNickname = [NSMutableString stringWithFormat:@"⚔/%@/%@", badgeVersion[1], mutableNickname];
                }
                else if ([badgeType isEqualToString:@"bits"]) {
                    mutableNickname = [NSMutableString stringWithFormat:@"🎉/%@/%@", badgeVersion[1], mutableNickname];
                }
                
            }
        }
    }

    return mutableNickname;
}

#pragma mark -
#pragma mark Helper Functions

- (BOOL)pluginIsEnabledForClient:(IRCClient *)client
{
    NSString *serverAddress = [[client config] serverAddress];

    // Check if we are connected to a twitch.tv server
    if ([[serverAddress lowercaseString] hasSuffix:@".twitch.tv"]) {
        return YES;
    }

    // Check if we are connected to a manually enabled server
    NSArray *manuallyEnabledServers = [RZUserDefaults() arrayForKey:@"TPITextualKappaServers"];
    
    if ([manuallyEnabledServers count] > 0) {
        for (NSDictionary *serverDictionary in manuallyEnabledServers) {
            
            for (id key in serverDictionary) {
                NSString *server = [serverDictionary valueForKey:key];
                if ([[server lowercaseString] isEqualToString:[serverAddress lowercaseString]]) {
                    return YES;
                }
            }
        }
    }

    return NO;
}

#pragma mark -
#pragma mark Preference Pane

- (NSString *)pluginPreferencesPaneMenuItemName
{
    return @"TextualKappa";
}

- (NSView *)pluginPreferencesPaneView
{
    return self.preferenceView;
}


- (void)updatePreferences
{
}

- (IBAction)preferenceChanged:(id)sender
{
    [self updatePreferences];
}

- (void)editTableView:(NSTableView *)tableView
{
    NSInteger rowSelection = ([tableView numberOfRows] - 1);

    [tableView scrollRowToVisible:rowSelection];
    [tableView editColumn:0 row:rowSelection withEvent:nil select:YES];
}

- (void)onAddServer:(id)sender
{
    [[self serversArrayController] add:nil];

    [self editTableView:[self serversTable]];
}

@end
