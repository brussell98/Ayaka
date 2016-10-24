import 'dart:io';
import 'package:discord/discord.dart';
import 'package:discord/discord_vm.dart';
import 'package:yaml/yaml.dart';
import 'ChannelConfig.dart';

Client bot;
String commandPrefix;
Map<String, Function> commands = new Map<String, Function>();
Map<String, ChannelConfig> channelConfig = new Map<String, ChannelConfig>();
Map<String, int> last_message_time = new Map<String, int>();
Map<String, String> last_message_text = new Map<String, String>();
RegExp discord_link_regex = new RegExp(r'discord(\.gg|app\.com\/invite|\.me)\/[A-Za-z0-9\-]+', caseSensitive: false);
RegExp link_regex = new RegExp(r'<?(https?:\/\/(?:\S+\.|(?![\s]+))[^\s\.]+\.[^\s]{2,}|\S+\.[^\s]+\.[^\s]{2,})>?', caseSensitive: false);

main() async {
	YamlMap config = loadYaml(await new File('config.yaml').readAsString());

	for (dynamic node in config.keys) {
		if (node != 'global')
			channelConfig[node.toString()] = new ChannelConfig(
				mods: config[node]['mods'] == null ? config['global']['mods'] : config[node]['mods'],
				whitelist: config[node]['whitelist'] == null ? config['global']['whitelist'] : config[node]['whitelist'],
				slow_mode: config[node]['slow_mode'] == null ? config['global']['slow_mode'] : config[node]['slow_mode'],
				caps_spam: config[node]['caps_spam'] == null ? config['global']['caps_spam'] : config[node]['caps_spam'],
				block_links: config[node]['block_links'] == null ? config['global']['block_links'] : config[node]['block_links'],
				blacklisted_words: config[node]['blacklisted_words'] == null ? config['global']['blacklisted_words'] : config[node]['blacklisted_words'],
				mentions_spam: config[node]['mentions_spam'] == null ? config['global']['mentions_spam'] : config[node]['mentions_spam'],
				repeat_spam: config[node]['repeat_spam'] == null ? config['global']['repeat_spam'] : config[node]['repeat_spam']
			);
	}

	commandPrefix = config['global']['prefix'];
	registerCommands();
	configureDiscordForVM();
	bot = new Client(config['global']['token'], new ClientOptions(disableEveryone: true, messageCacheSize: 5, forceFetchMembers: false));

	bot.onReady.listen(onReady);
	bot.onMessage.listen(onMessage);
	bot.onMessageUpdate.listen(onMessageUpdate);
}

onReady(ReadyEvent e) {
	print('Ayaka is online!');
}

onMessage(MessageEvent e) {
	if (e.message.channel is DMChannel || !channelConfig.containsKey(e.message.channel.id))
		return null;

	Message m = e.message;

	if (channelConfig[m.channel.id].mods.contains(m.author.id) && m.content.startsWith(commandPrefix))
		return handlePossibleCommand(m);

	if (channelConfig[m.channel.id].whitelist.contains(m.author.id))
		return null;

	if (channelConfig[m.channel.id].mentions_spam['enabled'])
		checkMentions(m);

	if (channelConfig[m.channel.id].slow_mode['enabled'])
		slowmodeCheck(m);

	if (channelConfig[m.channel.id].repeat_spam['enabled'])
		repeatCheck(m);

	if (channelConfig[m.channel.id].block_links['enabled'])
		linkCheck(m);

	if (channelConfig[m.channel.id].blacklisted_words.length != 0)
		blacklistCheck(m);

	if (channelConfig[m.channel.id].caps_spam['enabled'])
		checkCaps(m);
}

onMessageUpdate(MessageUpdateEvent e) {
	if (e.newMessage.channel is DMChannel || !channelConfig.containsKey(e.newMessage.channel.id))
		return null;

	Message m = e.newMessage;

	if (channelConfig[m.channel.id].whitelist.contains(m.author.id))
		return null;

	if (channelConfig[m.channel.id].mentions_spam['enabled'])
		checkMentions(m);

	if (channelConfig[m.channel.id].block_links['enabled'])
		linkCheck(m);

	if (channelConfig[m.channel.id].blacklisted_words.length != 0)
		blacklistCheck(m);

	if (channelConfig[m.channel.id].caps_spam['enabled'])
		checkCaps(m);
}

checkMentions(Message m) {
	if (m.mentions.length >= channelConfig[m.channel.id].mentions_spam['threshold']) {
		switch (channelConfig[m.channel.id].mentions_spam['action']) {
			case 'kick':
				m.member.kick();
				m.delete();
				print('User kicked for mention spam: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
				break;
			case 'ban':
				m.member.ban();
				m.delete();
				print('User banned for mention spam: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
				break;
			default:
				m.delete();
				print('Message deleted for mention spam: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
		}
	}
}

slowmodeCheck(Message m) {
	int sent = m.timestamp.millisecondsSinceEpoch;
	if (last_message_time[m.author.id] != null && sent - last_message_time[m.author.id] < channelConfig[m.channel.id].slow_mode['time']) {
		print('Message deleted from ${m.author.username} (${m.author.id}) because of slow mode');
		return m.delete();
	}
	last_message_time[m.author.id] = sent;
}

repeatCheck(Message m) {
	String text = channelConfig[m.channel.id].repeat_spam['ignore_case'] ? m.content.toLowerCase() : m.content;
	if (last_message_text[m.author.id] != null && last_message_text[m.author.id] == text) {
		print('Message deleted from ${m.author.username} (${m.author.id}) because of repeat message');
		return m.delete();
	}
	last_message_text[m.author.id] = text;
}

linkCheck(Message m) {
	if (discord_link_regex.hasMatch(m.content)) {
		print('Message deleted for containing link: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
		return m.delete();
	}

	if (!channelConfig[m.channel.id].block_links['invites_only']) {
		String link = link_regex.stringMatch(m.content);
		if (link != null) {
			if (!channelConfig[m.channel.id].block_links['allow_non_embed'] || (!link.startsWith('<') && !link.endsWith('>'))) {
				print('Message deleted for containing link: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
				return m.delete();
			}
		}
	}
}

blacklistCheck(Message m) {
	String lower = m.content.toLowerCase();
	for (String word in channelConfig[m.channel.id].blacklisted_words) {
		if (lower.contains(word)) {
			print("Message deleted for containing blacklisted word '$word': ${m.author.username} (${m.author.id})\nMessage: ${m.content}");
			return m.delete();
		}
	}
}

checkCaps(Message m) {
	if (channelConfig[m.channel.id].caps_spam_regex.hasMatch(m.content)) {
		print('Message deleted for containing too many caps: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
		return m.delete();
	}
}

// Commands below

registerCommands() {
	commands['slow mode'] = (Message m, String args) {
		switch (args.toLowerCase()) {
			case 'enable':
			case 'on':
				channelConfig[m.channel.id].slow_mode['enabled'] = true;
				break;
			case 'disable':
			case 'off':
				channelConfig[m.channel.id].slow_mode['enabled'] = false;
				break;
			default:
				try {
					double time = double.parse(args);
					channelConfig[m.channel.id].slow_mode['enabled'] = true;
					channelConfig[m.channel.id].slow_mode['time'] = time;
				} catch(error) {
					m.channel.sendMessage('Invalid time');
				}
		};
	};
}

handlePossibleCommand(Message m) {

}
