import 'dart:io';
import 'package:discord/discord.dart';
import 'package:yaml/yaml.dart';
import 'ChannelConfig.dart';

Client bot;
String commandPrefix;
Map<String, ChannelConfig> channelConfig = new Map<String, ChannelConfig>();

Map<String, int> last_message = new Map();
RegExp discord_link_regex = new RegExp(r'(discord\.gg\/[A-Za-z0-9]+|discordapp\.com\/invite\/[A-Za-z0-9]+)', caseSensitive: false);
RegExp link_regex = new RegExp(r'<?(https?:\/\/(?:\S+\.|(?![\s]+))[^\s\.]+\.[^\s]{2,}|\S+\.[^\s]+\.[^\s]{2,})>?', caseSensitive: false);

main() async {
	YamlMap config = loadYaml(await new File('config.yaml').readAsString());

	for (dynamic node in config.keys) {
		if (node != 'global')
			channelConfig[node.toString()] = new ChannelConfig(
				whitelist: config[node]['whitelist'] == null ? config['global']['whitelist'] : config[node]['whitelist'],
				slow_mode: config[node]['slow_mode'] == null ? config['global']['slow_mode'] : config[node]['slow_mode'],
				caps_block: config[node]['caps_block'] == null ? config['global']['caps_block'] : config[node]['caps_block'],
				links_block: config[node]['links_block'] == null ? config['global']['links_block'] : config[node]['links_block'],
				blacklisted_words: config[node]['blacklisted_words'] == null ? config['global']['blacklisted_words'] : config[node]['blacklisted_words']
			);
	}

	commandPrefix = config['global']['prefix'];
	bot = new Client(config['global']['token'], new ClientOptions(disableEveryone: true, messageCacheSize: 5, forceFetchMembers: false));

	bot.onReady.listen(onReady);
	bot.onMessage.listen(onMessage);
}

onReady(ReadyEvent e) {
	print('Eirene is online!');
}

onMessage(MessageEvent e) {
	if (e.message.channel is DMChannel)
		return;

	Message m = e.message;
	print('[${new DateTime.now().toString()}] ${m.guild.name} > ${m.channel.name} > ${m.author.username}: ${m.content}');

	if (!channelConfig.containsKey(m.channel.id) || channelConfig[m.channel.id].whitelist.contains(m.author.id))
		return;

	if (channelConfig[m.channel.id].slow_mode['enabled'])
		slowmodeCheck(m);

	if (channelConfig[m.channel.id].links_block['enabled'])
		linkCheck(m);

	if (channelConfig[m.channel.id].blacklisted_words.length != 0)
		blacklistCheck(m);

	if (channelConfig[m.channel.id].caps_block['enabled'])
		checkCaps(m);
}

slowmodeCheck(Message m) {
	int sent = m.timestamp.millisecondsSinceEpoch;
	if (last_message[m.author.id] != null && sent - last_message[m.author.id] < channelConfig[m.channel.id].slow_mode['time'])
		return m.delete();

	last_message[m.author.id] = sent;
}

linkCheck(Message m) {
	if (discord_link_regex.hasMatch(m.content))
		return m.delete();

	if (!channelConfig[m.channel.id].links_block['invites_only']) {
		String link = link_regex.stringMatch(m.content);
		if (link != null) {
			if (!channelConfig[m.channel.id].links_block['allow_non_embed'] || (!link.startsWith('<') && !link.endsWith('>')))
				return m.delete();
		}
	}
}

blacklistCheck(Message m) {
	String lower = m.content.toLowerCase();
	for (String word in channelConfig[m.channel.id].blacklisted_words) {
		if (lower.contains(word))
			return m.delete();
	}
}

checkCaps(Message m) {
	if (channelConfig[m.channel.id].caps_block_regex.hasMatch(m.content))
		return m.delete();
}
