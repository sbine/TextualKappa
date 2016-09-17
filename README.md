# TextualKappa
TextualKappa is a Twitch.tv chat plugin for the Textual IRC client that adds support for in-line emotes and subscriber/Turbo nickname indicators.

![screenshot](http://sarabine.com/i/Screen%20Shot%202015-11-11%20at%209.28.29%20PM.png)

## Installation
1. Navigate to Textual Preferences > Addons > Installed Addons
2. Click the 'Open In Finder' button
3. Move your downloaded copy of [TextualKappa.bundle](https://github.com/sbine/TextualKappa/releases/latest) (unzipped) into the Extensions folder
4. Restart Textual

## To-Do
- ~~Automatically send the necessary CAP requests to Twitch's IRC server on-connect~~
- ~~Render emoticons in the plugin itself (eliminating the need for the companion JS)~~ Used [xlexi's method](https://github.com/xlexi/Textual-Inline-Media) of automatically injecting CSS/JS
- ~~Support channel-specific subscriber icons~~
- ~~Support Twitch mod status (`user-type`)~~
- ~~Support emotes sent in actions~~
- Support emotes sent in own messages
- ~~Support broadcaster icon~~
- Respect `color` preference for display name
- ~~Respect capitalization preference for display name~~
- Handle deleted messages
- ~~Add preferences to support enabling/disabling the plugin~~
- Add support for [other Twitch.tv IRCv3 features](https://github.com/justintv/Twitch-API/blob/master/IRC.md)
- ~~Add support for [BetterTTV emotes](https://api.betterttv.net/emotes)~~
