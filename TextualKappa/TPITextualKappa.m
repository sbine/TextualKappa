//
//  TPITextualKappa.m
//  TextualKappa
//
//  Created by Sara on 11/3/15.
//  Copyright © 2015 sbine. All rights reserved.
//

#import "TPITextualKappa.h"

@interface TPITextualKappa ()

@end

@implementation TPITextualKappa

- (void)pluginLoadedIntoMemory
{
    // TODO: automatically send Twitch.tv CAP requests
    // quote CAP REQ :twitch.tv/tags
    // quote CAP REQ :twitch.tv/membership
    // quote CAP REQ :twitch.tv/commands

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(logControllerViewFinishedLoading:)
                   name:TVCLogControllerViewFinishedLoadingNotification
                 object:nil];
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

        // Emoticons!
        if ((messageTags[@"emotes"] != nil) && ([input params][1] != nil)) {

            NSString *messageString = [input params][1];
            messageString = [self replaceEmoticonsInString:messageString withEmoteIndices:messageTags[@"emotes"]];

            mutableParams[1] = messageString;
        }

        [senderInfo setNickname:nickname];
        [input setParams:mutableParams];
    }

    return input;
}

- (void) logControllerViewFinishedLoading:(NSNotification *)notification
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

            [head appendChild:cssInclude];
            [head appendChild:jsInclude];

        }
    }];
}

- (NSString *)replaceEmoticonsInString:(NSString *)messageString withEmoteIndices:(NSString *)emoteIndices
{
    NSMutableString *replacedString = [messageString mutableCopy];

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

    // Sort the emoticon dictionary in descending index order so in-place replacements don't invalidate subsequent indices
    NSArray *keys = [emoticonRangeDictionary allKeys];
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
        NSString *emoticonId = emoticonRangeDictionary[emoticonIndex];

        // TODO: remove the need for placeholder :twitch_<emote>:
        replacedString = [[replacedString stringByReplacingCharactersInRange:NSRangeFromString(emoticonIndex) withString:[NSString stringWithFormat:@":twitch_%@:", emoticonId]] mutableCopy];
    }

    return replacedString;
}

@end
