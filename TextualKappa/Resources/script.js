var twitchEmoteRegex = new RegExp(':twitch_(\\d+):', 'g');
var channelSubscriberRegex = new RegExp('(💎)', 'g');
var twitchBadgeRegex = new RegExp('(⚡|⚔|🔨|🔰|🔧)', 'g');
var subscriberImages = {};

Textual.newMessagePostedToView = function(line)
{
    var element = document.getElementById("line-" + line);

    var message = element.getElementsByClassName('innerMessage');
    var sender = element.getElementsByClassName('sender');

    if (message[0] !== undefined) {
        var twitchEmoteMatches = message[0].innerText.match(twitchEmoteRegex);
        if (twitchEmoteMatches && twitchEmoteMatches.length > 0) {
            message[0].innerHTML = message[0].innerHTML.replace(twitchEmoteRegex, twitchEmoteRegexReplacer);
        }
    }

    if (sender[0] !== undefined) {
        var nickname = sender[0].getAttribute('nickname');

        var body = document.body;
        var channel = body.getAttribute('channelname').replace('#', '');

        if (subscriberImages[channel]) {
            // Remove subscriber emoji from the nickname and prepend the fetched icon to the sender line
            var channelSubscriberMatches = sender[0].innerText.match(channelSubscriberRegex);
            if (channelSubscriberMatches && channelSubscriberMatches.length > 0) {
                sender[0].innerHTML = sender[0].innerHTML.replace(channelSubscriberRegex, '');
                sender[0].innerHTML = subscriberIconForChannel(channel) + '' + sender[0].innerHTML;
            }
            nickname = nickname.replace(channelSubscriberRegex, '');
        }

        var twitchBadgeMatches = sender[0].innerText.match(twitchBadgeRegex);
        if (twitchBadgeMatches && twitchBadgeMatches.length > 0) {

            for (var i = twitchBadgeMatches.length - 1; i >= 0; i--) {
                // Remove Twitch user-type emojis from the nickname and prepend them to the sender line, in reverse order
                sender[0].innerHTML = sender[0].innerHTML.replace(twitchBadgeMatches[i], '');
                sender[0].innerHTML = twitchBadgeForEmoticon(twitchBadgeMatches[i]) + '' + sender[0].innerHTML;
            }

            nickname = nickname.replace(twitchBadgeRegex, '');
        }

        // Strip out images and replace escaped content in the 'nickname' attribute
        nickname = nickname.replace(/\\s/g, ' ');
        sender[0].setAttribute('nickname', nickname);

        // Broadcaster icon
        if (nickname.toLowerCase() === channel.toLowerCase()) {
            sender[0].innerHTML = '<img class="tw-broadcaster" src="https://chat-badges.s3.amazonaws.com/broadcaster.png"> ' + sender[0].innerHTML;
        }
    }

    element.className = element.className + ' tw-line';

    updateNicknameAssociatedWithNewMessage(element);
}

Textual.viewBodyDidLoadKappa = function()
{
    var body = document.body;

    if (parseInt(body.getAttribute('data-twitch-channel')) === 1) {
        var channel = body.getAttribute('channelname').replace('#', '');
        getJSONFromUrl("https://api.twitch.tv/kraken/chat/" + channel + "/badges", function(response) {
            resp = JSON.parse(response);
            if (resp.subscriber !== undefined) {
                var subscriberIcon = resp.subscriber.image.replace('http:', 'https:');
                subscriberImages[channel] = subscriberIcon;
            }
        });
    }
}

function twitchEmoteRegexReplacer(str, match1) {
    return '<img class="tw-emoticon" src="https://static-cdn.jtvnw.net/emoticons/v1/' + match1 + '/1.0">';
}

function twitchBadgeForEmoticon(emoticon) {
    var userType = '';
    switch (emoticon) {
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
    return '<img class="tw-emoticon" src="https://chat-badges.s3.amazonaws.com/' + userType + '.png"> ';
}

function subscriberIconForChannel(channel) {
    return '<img class="tw-subscriber" src="' + subscriberImages[channel] + '"> ';
}

function getJSONFromUrl(url, callback) {
    var xmlhttp;
    xmlhttp = new XMLHttpRequest();
    xmlhttp.onreadystatechange = function() {
        if (xmlhttp.readyState == XMLHttpRequest.DONE && xmlhttp.status == 200){
            callback(xmlhttp.responseText);
        }
    }
    xmlhttp.open("GET", url, true);
    xmlhttp.send();
}