var TextualKappa = {};

TextualKappa.twitchEmoteRegex = new RegExp(':twitch_(\\d+):', 'g');
TextualKappa.channelSubscriberRegex = new RegExp('(💎)', 'g');
TextualKappa.twitchBadgeRegex = new RegExp('(⚡|⚔|🔨|🔰|🔧)', 'g');
TextualKappa.betterTTVGlobalEmoteRegex = 'ForeverAlone';
TextualKappa.betterTTVChannelEmoteRegex = 'ForeverAlone';
TextualKappa.subscriberImages = {};
TextualKappa.betterTTVGlobalEmotes = {};
TextualKappa.betterTTVChannelEmotes = {};

TextualKappa.isTwitchChannel = function() {
    return parseInt(document.body.getAttribute('data-twitch-channel')) === 1;
}

TextualKappa.updateDisplayName = function(name) {
    TextualKappa.displayName = name;
}

TextualKappa.twitchViewDidLoad = function()
{
    if (TextualKappa.isTwitchChannel()) {
        var channel = document.body.getAttribute('channelname').replace('#', '');

        if (TextualKappa.subscriberImages[channel] === undefined) {
            getJSONFromUrl("https://api.twitch.tv/kraken/chat/" + channel + "/badges", function(response) {
                resp = JSON.parse(response);
                if (resp.subscriber !== undefined && resp.subscriber !== null) {
                    var subscriberIcon = resp.subscriber.image.replace('http:', 'https:');
                    TextualKappa.subscriberImages[channel] = subscriberIcon;
                }
            });
        }

        if (TextualKappa.betterTTVGlobalEmotes.length === undefined) {
            getJSONFromUrl("https://api.betterttv.net/emotes", function(response) {
                resp = JSON.parse(response);
                if (resp.emotes !== undefined) {
                    for (var i = 0; i < resp.emotes.length; i++) {
                        TextualKappa.betterTTVGlobalEmotes[resp.emotes[i].regex.replace('(', '').replace(')', '')] = resp.emotes[i].url;
                    }
                    for (var emote in TextualKappa.betterTTVGlobalEmotes) {
                        if (TextualKappa.betterTTVGlobalEmotes.hasOwnProperty(emote)) {
                            TextualKappa.betterTTVGlobalEmoteRegex = TextualKappa.betterTTVGlobalEmoteRegex + '|' + emote;
                        }
                    }
                }
                TextualKappa.betterTTVGlobalEmoteRegex = new RegExp('\\b(' + TextualKappa.betterTTVGlobalEmoteRegex + ')\\b', 'g');
            });
        }

        if (TextualKappa.betterTTVChannelEmotes[channel] === undefined) {
            getJSONFromUrl("https://api.betterttv.net/2/channels/" + channel, function(response) {
                resp = JSON.parse(response);
                if (resp.emotes !== undefined) {
                    for (var i = 0; i < resp.emotes.length; i++) {
                        TextualKappa.betterTTVChannelEmotes[resp.emotes[i].code] = "//cdn.betterttv.net/emote/" + resp.emotes[i].id + "/1x";
                    }
                    for (var emote in TextualKappa.betterTTVChannelEmotes) {
                        if (TextualKappa.betterTTVChannelEmotes.hasOwnProperty(emote)) {
                            TextualKappa.betterTTVChannelEmoteRegex = TextualKappa.betterTTVChannelEmoteRegex + '|' + emote;
                        }
                    }
                }
                TextualKappa.betterTTVChannelEmoteRegex = new RegExp('\\b(' + TextualKappa.betterTTVChannelEmoteRegex + ')\\b', 'g');
            });
        }
    }
}

Textual.newMessagePostedToView = function(line)
{
    if (TextualKappa.isTwitchChannel()) {
        var element = document.getElementById("line-" + line);

        var message = element.getElementsByClassName('innerMessage');
        var sender = element.getElementsByClassName('sender');

        if (message[0] !== undefined) {
            message = message[0];

            // Twitch emotes
            var twitchEmoteMatches = message.innerText.match(TextualKappa.twitchEmoteRegex);
            if (twitchEmoteMatches && twitchEmoteMatches.length > 0) {
                message.innerHTML = message.innerHTML.replace(TextualKappa.twitchEmoteRegex, twitchEmoteRegexReplacer);
            }
        }

        if (sender[0] !== undefined) {
            sender = sender[0];

            var nickname = sender.getAttribute('nickname');
            var channel = document.body.getAttribute('channelname').replace('#', '');

            // Channel subscriber icons
            if (TextualKappa.subscriberImages[channel]) {
                // Remove subscriber emoji from the nickname and prepend the fetched icon to the sender line
                var channelSubscriberMatches = sender.innerText.match(TextualKappa.channelSubscriberRegex);
                if (channelSubscriberMatches && channelSubscriberMatches.length > 0) {
                    sender.innerHTML = sender.innerHTML.replace(TextualKappa.channelSubscriberRegex, '');
                    sender.innerHTML = subscriberIconForChannel(channel) + '' + sender.innerHTML;
                }
                nickname = nickname.replace(TextualKappa.channelSubscriberRegex, '');
            }

            // Twitch staff / mods / Turbo icons
            var twitchBadgeMatches = sender.innerText.match(TextualKappa.twitchBadgeRegex);
            if (twitchBadgeMatches && twitchBadgeMatches.length > 0) {

                for (var i = twitchBadgeMatches.length - 1; i >= 0; i--) {
                    // Remove Twitch user-type emojis from the nickname and prepend them to the sender line, in reverse order
                    sender.innerHTML = sender.innerHTML.replace(twitchBadgeMatches[i], '');
                    sender.innerHTML = twitchBadgeForEmoticon(twitchBadgeMatches[i]) + '' + sender.innerHTML;
                }

                nickname = nickname.replace(TextualKappa.twitchBadgeRegex, '');
            }

            // BetterTTV emotes
            var betterTTVGlobalEmoteMatches = message.innerText.match(TextualKappa.betterTTVGlobalEmoteRegex);
            if (betterTTVGlobalEmoteMatches && betterTTVGlobalEmoteMatches.length > 0) {
                message.innerHTML = message.innerHTML.replace(TextualKappa.betterTTVGlobalEmoteRegex, betterTTVGlobalEmoteRegexReplacer);
            }

            // BetterTTV emotes
            var betterTTVChannelEmoteMatches = message.innerText.match(TextualKappa.betterTTVChannelEmoteRegex);
            if (betterTTVChannelEmoteMatches && betterTTVChannelEmoteMatches.length > 0) {
                message.innerHTML = message.innerHTML.replace(TextualKappa.betterTTVChannelEmoteRegex, betterTTVChannelEmoteRegexReplacer);
            }

            // Replace escaped content in the sender text
            sender.innerHTML = sender.innerHTML.replace(/\\s/g, ' ');

            if (TextualKappa.displayName !== undefined) {
                if (nickname.match(new RegExp('^' + TextualKappa.displayName + '$', 'i'))) {
                    sender.innerHTML = sender.innerHTML.replace(nickname, TextualKappa.displayName);
                }
            }

            // Replace escaped content in the 'nickname' attribute
            nickname = nickname.replace(/\\s/g, ' ');
            sender.setAttribute('nickname', nickname);

            // Broadcaster icon
            if (nickname.toLowerCase() === channel.toLowerCase()) {
                sender.innerHTML = '<img class="tw-broadcaster" src="https://chat-badges.s3.amazonaws.com/broadcaster.png"> ' + sender.innerHTML;
            }
        }

        element.className = element.className + ' tw-line';

        ConversationTracking.updateNicknameWithNewMessage(element);
    }
}

function twitchEmoteRegexReplacer(str, match1) {
    return '<img class="tw-emoticon" src="https://static-cdn.jtvnw.net/emoticons/v1/' + match1 + '/1.0">';
}

function betterTTVGlobalEmoteRegexReplacer(str, match1) {
    if (TextualKappa.betterTTVGlobalEmotes[str] !== undefined) {
        return '<img class="tw-bttv-emoticon" src="https:' + TextualKappa.betterTTVGlobalEmotes[str] + '" alt="' + str + ' (bttv)" title="' + str + ' (bttv)">';
    } else {
        return str;
    }
}

function betterTTVChannelEmoteRegexReplacer(str, match1) {
    if (TextualKappa.betterTTVChannelEmotes[str] !== undefined) {
        return '<img class="tw-bttv-emoticon" src="https:' + TextualKappa.betterTTVChannelEmotes[str] + '" alt="' + str + ' (bttv)" title="' + str + ' (bttv)">';
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
    return '<img class="tw-subscriber" src="' + TextualKappa.subscriberImages[channel] + '"> ';
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