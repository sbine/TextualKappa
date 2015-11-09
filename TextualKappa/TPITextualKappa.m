//
//  TPITextualKappa.m
//  TextualKappa
//
//  Created by Sara on 11/3/15.
//  Copyright © 2015 sbine. All rights reserved.
//

#import "TPITextualKappa.h"

@interface TPITextualKappa ()

@property (nonatomic, strong) NSMutableArray *observedClients;

@end

@implementation TPITextualKappa

#pragma mark -
#pragma mark Plugin API Hooks

- (void)pluginLoadedIntoMemory
{
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

- (void)pluginWillBeUnloadedFromMemory
{
    [RZNotificationCenter() removeObserver:self];
}

- (IRCMessage *)interceptServerInput:(IRCMessage *)input for:(IRCClient *)client
{
    // Capture PRIVMSGs
    if ([[input command] isEqualToString:@"PRIVMSG"]) {

        // Check for the presence of IRCv3 message tags
        if ([input messageTags] != nil) {
            return [self interceptPrivmsgsKappaAddon:input senderInfo:[input sender] client:client];
        }
    }

    return input;
}

#pragma mark -
#pragma mark Twitch PRIVMSG Parsing

- (IRCMessage *)interceptPrivmsgsKappaAddon:(IRCMessage *)input senderInfo:(IRCPrefix *)senderInfo client:(IRCClient *)client
{
    // Make a mutable copy of message parameters to modify & return
    NSMutableArray *mutableParams = [[input params] mutableCopy];

    NSDictionary *messageTags = [input messageTags];

    // Check again for the presence of IRCv3 message tags, for science
    if (messageTags != nil) {

        NSString *nickname = senderInfo.nickname;

        // Twitch sends username capitalization preferences in the "display-name" key
        if ((messageTags[@"display-name"] != nil)) {

            // Ignore empty strings as Twitch sends them for users who have since been kicked from a channel
            if ([messageTags[@"display-name"] length] != 0) {
                nickname = messageTags[@"display-name"];
            }

        }

        // Is this user a subscriber to the current broadcast?
        if ((messageTags[@"subscriber"] != nil) && ([messageTags[@"subscriber"] integerValue] == 1)) {

            nickname = [NSString stringWithFormat:@"💎%@", nickname];

        }

        // Is this user a Twitch Turbo member?
        if ((messageTags[@"turbo"] != nil) && ([messageTags[@"turbo"] integerValue] == 1)) {

            nickname = [NSString stringWithFormat:@"⚡%@", nickname];

        }

        // Is this user a moderator or Twitch staff?
        if ((messageTags[@"user-type"] != nil)) {

            // Use standard emoji as placeholders
            if ([messageTags[@"user-type"]  isEqual:@"mod"]) {
                nickname = [NSString stringWithFormat:@"⚔%@", nickname];
            } else if ([messageTags[@"user-type"]  isEqual:@"global_mod"]) {
                nickname = [NSString stringWithFormat:@"🔨%@", nickname];
            } else if ([messageTags[@"user-type"]  isEqual:@"admin"]) {
                nickname = [NSString stringWithFormat:@"🔰%@", nickname];
            } else if ([messageTags[@"user-type"]  isEqual:@"staff"]) {
                nickname = [NSString stringWithFormat:@"🔧%@", nickname];
            }
            
        }

        // Emoticons!
        if ((messageTags[@"emotes"] != nil) && ([input params][1] != nil)) {

            NSString *messageString = [input params][1];
            NSDictionary *emoteDirectives = [self getEmoticonDirectivesFromString:messageString withEmoteIndices:messageTags[@"emotes"]];
            messageString = [self replaceEmoticonsInString:messageString withEmoteDirectives:emoteDirectives];

            mutableParams[1] = messageString;
        }

        [senderInfo setNickname:nickname];
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
            DOMDocument *document = [[controller webView] mainFrameDocument];
            DOMNode *head = [[document getElementsByTagName:@"head"] item:0];
            NSBundle *mainBundle = [NSBundle bundleForClass:[self class]];

            NSString *cssPath = [mainBundle pathForResource:@"style" ofType:@"css" inDirectory:@"Resources"];
            NSString *jsPath = [mainBundle pathForResource:@"script" ofType:@"js" inDirectory:@"Resources"];

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
        NSString *serverAddress = [[client config] serverAddress];

        // Check if we are connected to a twitch.tv server
        if ([[serverAddress lowercaseString] hasSuffix:@"twitch.tv"] && [client isConnected] == YES) {
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
                    NSInteger startIndex = [[emoticonRange substringToIndex:positionOfDash.location] integerValue];
                    NSInteger endIndex = [[emoticonRange substringAfterIndex:positionOfDash.location] integerValue];
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

@end
