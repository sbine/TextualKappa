# TextualKappa
TextualKappa is a Twitch.tv chat plugin for the Textual IRC client that adds support for in-line emotes and subscriber/Turbo nickname indicators.

![screenshot](http://sarabine.com/i/Screen%20Shot%202015-11-07%20at%203.53.03%20PM.png)

## Notes
This plugin is in the early stages of development. Currently, it can only be built with the [latest Textual source](https://github.com/Codeux-Software/Textual) -- building on older versions will cause Textual to crash.

If you still want to use this plugin, follow the instructions in the [Textual plugin development guide](https://www.codeux.com/textual/help/private/wiki-content/Writing-Plugins%3A-Basic-Tutorial/document.pdf) but replace all paths to Textual with your local build.

## To-Do
- Automatically send the necessary CAP requests to Twitch's IRC server on-connect
- ~~Render emoticons in the plugin itself (eliminating the need for the companion JS)~~ Used [xlexi's method](https://github.com/xlexi/Textual-Inline-Media) of automatically injecting CSS/JS
- Support channel-specific subscriber icons/actual Turbo icon
- Support Twitch mod status (`user-type`)
