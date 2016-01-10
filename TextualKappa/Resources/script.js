var twitchEmoteRegex = new RegExp(':twitch_(\\d+):', 'g');
var channelSubscriberRegex = new RegExp('(💎)', 'g');
var twitchBadgeRegex = new RegExp('(⚡|⚔|🔨|🔰|🔧)', 'g');
var betterTTVEmoteRegex = 'ForeverAlone';
var subscriberImages = {};
var betterTTVEmotes = {};

Textual.newMessagePostedToView = function(line)
{
    if (document.body.dataset.twitchChannel === "1") {
        var element = document.getElementById("line-" + line);

        var message = element.getElementsByClassName('innerMessage');
        var sender = element.getElementsByClassName('sender');

        if (message[0] !== undefined) {
            message = message[0];

            // Twitch emotes
            var twitchEmoteMatches = message.innerText.match(twitchEmoteRegex);
            if (twitchEmoteMatches && twitchEmoteMatches.length > 0) {
                message.innerHTML = message.innerHTML.replace(twitchEmoteRegex, twitchEmoteRegexReplacer);
            }
        }

        if (sender[0] !== undefined) {
            sender = sender[0];

            var nickname = sender.getAttribute('nickname');
            var channel = document.body.getAttribute('channelname').replace('#', '');

            // Channel subscriber icons
            if (subscriberImages[channel]) {
                // Remove subscriber emoji from the nickname and prepend the fetched icon to the sender line
                var channelSubscriberMatches = sender.innerText.match(channelSubscriberRegex);
                if (channelSubscriberMatches && channelSubscriberMatches.length > 0) {
                    sender.innerHTML = sender.innerHTML.replace(channelSubscriberRegex, '');
                    sender.innerHTML = subscriberIconForChannel(channel) + '' + sender.innerHTML;
                }
                nickname = nickname.replace(channelSubscriberRegex, '');
            }

            // Twitch staff / mods / Turbo icons
            var twitchBadgeMatches = sender.innerText.match(twitchBadgeRegex);
            if (twitchBadgeMatches && twitchBadgeMatches.length > 0) {

                for (var i = twitchBadgeMatches.length - 1; i >= 0; i--) {
                    // Remove Twitch user-type emojis from the nickname and prepend them to the sender line, in reverse order
                    sender.innerHTML = sender.innerHTML.replace(twitchBadgeMatches[i], '');
                    sender.innerHTML = twitchBadgeForEmoticon(twitchBadgeMatches[i]) + '' + sender.innerHTML;
                }

                nickname = nickname.replace(twitchBadgeRegex, '');
            }

            // BetterTTV emotes
            var betterTTVEmoteMatches = message.innerText.match(betterTTVEmoteRegex);
            if (betterTTVEmoteMatches && betterTTVEmoteMatches.length > 0) {
                message.innerHTML = message.innerHTML.replace(betterTTVEmoteRegex, betterTTVEmoteRegexReplacer);
            }

            // Replace escaped content in the sender text
            sender.innerHTML = sender.innerHTML.replace(/\\s/g, ' ');

            // Replace escaped content in the 'nickname' attribute
            nickname = nickname.replace(/\\s/g, ' ');
            sender.setAttribute('nickname', nickname);

            // Broadcaster icon
            if (nickname.toLowerCase() === channel.toLowerCase()) {
                sender.innerHTML = '<img class="tw-broadcaster" src="https://chat-badges.s3.amazonaws.com/broadcaster.png"> ' + sender.innerHTML;
            }
        }

        element.className = element.className + ' tw-line';

        updateNicknameAssociatedWithNewMessage(element);
    }
}

Textual.viewBodyDidLoadKappa = function()
{
    if (parseInt(document.body.getAttribute('data-twitch-channel')) === 1) {
        var channel = document.body.getAttribute('channelname').replace('#', '');

        getJSONFromUrl("https://api.twitch.tv/kraken/chat/" + channel + "/badges", function(response) {
            resp = JSON.parse(response);
            if (resp.subscriber !== undefined) {
                var subscriberIcon = resp.subscriber.image.replace('http:', 'https:');
                subscriberImages[channel] = subscriberIcon;
            }
        });

        getJSONFromUrl("https://api.betterttv.net/emotes", function(response) {
            resp = JSON.parse(response);
            if (resp.emotes !== undefined) {
                for (var i = 0; i < resp.emotes.length; i++) {
                    betterTTVEmotes[resp.emotes[i].regex.replace('(', '').replace(')', '')] = resp.emotes[i].url;
                }
                for (var emote in betterTTVEmotes) {
                    if (betterTTVEmotes.hasOwnProperty(emote)) {
                        betterTTVEmoteRegex = betterTTVEmoteRegex + '|' + emote;
                    }
                }
            }
            betterTTVEmoteRegex = new RegExp('\\b(' + betterTTVEmoteRegex + ')\\b', 'g');
        });
    }
}

function twitchEmoteRegexReplacer(str, match1) {
    return '<img class="tw-emoticon" src="https://static-cdn.jtvnw.net/emoticons/v1/' + match1 + '/1.0">';
}

function betterTTVEmoteRegexReplacer(str, match1) {
    if (betterTTVEmotes[str] !== undefined) {
        return '<img class="tw-bttv-emoticon" src="https:' + betterTTVEmotes[str] + '" alt="' + str + ' (bttv)" title="' + str + ' (bttv)">';
    } else {
        return str;
    }
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