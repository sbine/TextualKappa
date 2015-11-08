var twitchEmoteRegex = new RegExp(':twitch_(\\d+):', 'g');

function twitchEmoteRegexReplacer(str, match1) {
    return '<img class="tw-emoticon" src="https://static-cdn.jtvnw.net/emoticons/v1/' + match1 + '/1.0">';
}

Textual.newMessagePostedToView = function(line)
{
    var element = document.getElementById("line-" + line);

    var message = element.getElementsByClassName('innerMessage');
    var twitchMatches = message[0].innerText.match(twitchEmoteRegex);

    if (twitchMatches && twitchMatches.length > 0) {
        message[0].innerHTML = message[0].innerHTML.replace(twitchEmoteRegex, twitchEmoteRegexReplacer);
    }

    updateNicknameAssociatedWithNewMessage(element);
}