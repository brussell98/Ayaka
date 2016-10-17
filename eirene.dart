import 'dart:io';
import 'package:discord/discord.dart';
import 'package:yaml/yaml.dart';

Client bot;
YamlMap config;

Map<String, int> last_message = new Map();
RegExp discord_link_regex = new RegExp(r'(discord\.gg\/[A-Za-z0-9]+|discordapp\.com\/invite\/[A-Za-z0-9]+)', caseSensitive: false);
RegExp link_regex = new RegExp(r'<?(https?:\/\/(?:\S+\.|(?![\s]+))[^\s\.]+\.[^\s]{2,}|\S+\.[^\s]+\.[^\s]{2,})>?', caseSensitive: false);
RegExp caps_spam;

main() async {
	config = loadYaml(await new File('config.yaml').readAsString());
	if (config['caps_block']['enabled'] && config['caps_block']['threshold'] < 3)
		throw 'The caps block threshold must be at least 3';
	caps_spam = new RegExp('[A-Z][A-Z ]{' + (config['caps_block']['threshold'] - 2).toString() + '}[A-Z]');
	bot = new Client(config['token'], new ClientOptions(disableEveryone: true, messageCacheSize: 5, forceFetchMembers: false));

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

	if (config['whitelist'].contains(m.author.id) || !config['channels'].contains(m.channel.id))
		return;

	if (config['slow_mode']['enabled'])
		slowmodeCheck(m);

	if (config['links_block']['enabled'])
		linkCheck(m);

	if (config['blacklisted_words'].length != 0)
		blacklistCheck(m);

	if (config['caps_block']['enabled'])
		checkCaps(m);
}

slowmodeCheck(Message m) {
	int sent = m.timestamp.millisecondsSinceEpoch;
	if (last_message[m.author.id] != null && sent - last_message[m.author.id] < config['slow_mode']['time'])
		return m.delete();

	last_message[m.author.id] = sent;
}

linkCheck(Message m) {
	if (discord_link_regex.hasMatch(m.content))
		return m.delete();

	if (!config['links_block']['invites_only']) {
		String link = link_regex.stringMatch(m.content);
		if (link != null) {
			if (!config['links_block']['allow_non_embed'] || (!link.startsWith('<') && !link.endsWith('>')))
				return m.delete();
		}
	}
}

blacklistCheck(Message m) {
	String lower = m.content.toLowerCase();
	for (String word in config['blacklisted_words']) {
		if (lower.contains(word))
			return m.delete();
	}
}

checkCaps(Message m) {
	if (caps_spam.hasMatch(m.content))
		return m.delete();
}
