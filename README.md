![Ayaka Shindou](http://i.imgur.com/jkowpFW.png)

A feature-rich moderation bot for your Discord channels.    
#### Features:
- Live setting changes through commands
- Settings per channel
- Checks message edits
- User whitelist
- Slow mode
- Removal of caps spam
- Removal of links and invites
- Word blacklist
- Stop mention spam
- Stop message repeating

#### [Support my projects on Patreon](http://patreon.com/brussell98) | [Discord Server](https://discord.gg/rkWPSdu) | [Discord-Dart Docs](https://www.dartdocs.org/documentation/discord/latest/)   

# Installing:
1. [Download and install the Dart VM for your OS.](https://www.dartlang.org/install)

2. Run `pub get` in the root directory of the bot.

3. [Create an application with a bot user.](https://discordapp.com/developers/applications/me) (Note the token)

4. Set up the `config.toml` file.

5. Add your bot to a server using `https://discordapp.com/oauth2/authorize?client_id=YOUR_CLIENT_ID&scope=bot`.

# config.toml

- Every channel that you want to moderate must be listed even if no settings are changed.
- All fields are required in each setting.
- As shown in the example file, settings can be overwritten per-channel.

##### token
The token given on the bot's application page (created above in step 3).

##### prefix
Used before commands to distinguish them from messages.

##### mods
Users that can use commands

##### whitelist
Users that the bot will not moderate. Mods are automatically included.

##### slow_mode
Restrict how many messages a user can send.   
`time` Milliseconds between allowed messages (seconds * 1000).

##### caps_removal
Remove messages containing many consecutive caps.   
`threshold` Max amount of consecutive caps to allow in a message.

##### block_links
Stop links and invites from being posted in chat.   
`invites_only` Only delete discord invites, allow other links.   
`allow_non_embed` Allow links wrapped in <> that don't show a preview.

##### blacklisted_words
Remove messages containing these words.

##### mentions_spam
Remove messages containing many mentions.   
`threshold` Number of mentions required to trigger this.   
`action` What action to take. (delete, kick, ban)

##### repeat_spam
Stop users from posting the same message multiple times.   
`ignore_case` Treat "ABC" and "abc" the same.

##### welcome
Greet new members. (This setting is not available globally)
`message` The message to send. `{user}` = their username. `{mention}` = mention them. `{server}` = the server's name

# Commands

|Command|Args|Example|
|-------|----|-------|
|!slow mode | `enable`, `on`, `disable`, `off`, or the `time between messages in ms` | !slow mode 5000<br>!slow mode enable|
|!whitelist | `Mention` the users to whitelist | !whitelist @Brussell @abalabahaha|
|!unwhitelist | `Mention` the users to remove from the whitelist | !unwhitelist @Brussell|
|!mod | `Mention` the users to mod | !mod @Brussell|
|!unmod | `Mention` the users to unmod | !unmod @Brussell|
|!caps removal | `enable`, `on`, `disable`, `off`, or the `threshold` | !caps removal 15<br>!caps removal enable|
|!mute | `Mention` the users to mute | !mute @Brussell|
|!unmute | `Mention` the users to unmute | !unmute @Brussell|
|!block links | `enable`, `on`, `disable`, `off`, `invites only` to only delete invites, `allow non-embeds` to allow suppressed links | !block links enable, allow non-embeds|
|!mentions spam | `enable`, `on`, `disable`, `off`, `number` of mentions to trigger action, `action` to take (delete, kick, or ban) | !mentions spam 10 ban<br>!repeat spam delete|
|!repeat spam | `enable`, `on`, `disable`, `off`, `ignore case` to ignore case (ABC = abc) | !repeat spam on ignore case<br>!repeat spam disable|
|!welcome | `disable`, `off`, `message` to greet with | !welcome Welcome to the server {user}!<br>!welcome disable|
