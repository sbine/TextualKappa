var twitchEmoteRegex = new RegExp(':twitch_(\\d+):', 'g');
var twitchBadgeRegex = new RegExp('(⚡|⚔|🔨|🔰|🔧)', 'g');

function twitchEmoteRegexReplacer(str, match1) {
    return '<img class="tw-emoticon" src="https://static-cdn.jtvnw.net/emoticons/v1/' + match1 + '/1.0">';
}

function twitchBadgeRegexReplacer(str, match1) {
    var userType = '';
    switch (match1) {
        case '⚔':
            userType = 'mod';
            break;
        case '🔨':
            userType = 'globalmod';
            break;
        case '🔰':
            userType = 'staff';
            break;
        case '🔧':
            userType = 'admin';
            break;
        case '⚡':
        default:
            userType = 'turbo';
            break;
    }
    return '<img class="tw-emoticon" src="https://chat-badges.s3.amazonaws.com/' + userType + '.png">';
}

function channelSubscriberRegexReplacer(str, match1) {
    return '<img class="tw-emoticon" src="https://chat-badges.s3.amazonaws.com/turbo.png">';
}

Textual.newMessagePostedToView = function(line)
{
    var element = document.getElementById("line-" + line);

    var message = element.getElementsByClassName('innerMessage');
    var sender = element.getElementsByClassName('sender');

    if (message[0].innerText !== undefined) {
        var twitchMatches = message[0].innerText.match(twitchEmoteRegex);
        if (twitchMatches && twitchMatches.length > 0) {
            message[0].innerHTML = message[0].innerHTML.replace(twitchEmoteRegex, twitchEmoteRegexReplacer);
        }
    }

    var twitchBadgeMatches = sender[0].innerText.match(twitchBadgeRegex);
    if (twitchBadgeMatches && twitchBadgeMatches.length > 0) {
        sender[0].innerHTML = sender[0].innerHTML.replace(twitchBadgeRegex, twitchBadgeRegexReplacer);
    }

    updateNicknameAssociatedWithNewMessage(element);
}
