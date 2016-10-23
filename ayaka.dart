import 'dart:io';
import 'package:discord/discord.dart';
import 'package:yaml/yaml.dart';
import 'ChannelConfig.dart';

Client bot;
String commandPrefix;
Map<String, Function> commands = new Map<String, Function>();
Map<String, ChannelConfig> channelConfig = new Map<String, ChannelConfig>();
Map<String, int> last_message = new Map();
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
				caps_block: config[node]['caps_block'] == null ? config['global']['caps_block'] : config[node]['caps_block'],
				links_block: config[node]['links_block'] == null ? config['global']['links_block'] : config[node]['links_block'],
				blacklisted_words: config[node]['blacklisted_words'] == null ? config['global']['blacklisted_words'] : config[node]['blacklisted_words'],
				mentions_block: config[node]['mentions_block'] == null ? config['global']['mentions_block'] : config[node]['mentions_block']
			);
	}

	commandPrefix = config['global']['prefix'];
	registerCommands();
	bot = new Client(config['global']['token'], new ClientOptions(disableEveryone: true, messageCacheSize: 5, forceFetchMembers: false));

	bot.onReady.listen(onReady);
	bot.onMessage.listen(onMessage);
	// Todo: on message edit
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

	if (channelConfig[m.channel.id].mentions_block['enabled'])
		checkMentions(m);

	if (channelConfig[m.channel.id].slow_mode['enabled'])
		slowmodeCheck(m);

	if (channelConfig[m.channel.id].links_block['enabled'])
		linkCheck(m);

	if (channelConfig[m.channel.id].blacklisted_words.length != 0)
		blacklistCheck(m);

	if (channelConfig[m.channel.id].caps_block['enabled'])
		checkCaps(m);
}

checkMentions(Message m) {
	if (m.mentions.length >= channelConfig[m.channel.id].mentions_block['threshold']) {
		switch (channelConfig[m.channel.id].mentions_block['action']) {
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
	if (last_message[m.author.id] != null && sent - last_message[m.author.id] < channelConfig[m.channel.id].slow_mode['time'])
		return m.delete();

	last_message[m.author.id] = sent;
}

linkCheck(Message m) {
	if (discord_link_regex.hasMatch(m.content)) {
		print('Message deleted for containing link: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
		return m.delete();
	}

	if (!channelConfig[m.channel.id].links_block['invites_only']) {
		String link = link_regex.stringMatch(m.content);
		if (link != null) {
			if (!channelConfig[m.channel.id].links_block['allow_non_embed'] || (!link.startsWith('<') && !link.endsWith('>'))) {
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
	if (channelConfig[m.channel.id].caps_block_regex.hasMatch(m.content)) {
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
