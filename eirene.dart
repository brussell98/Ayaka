import 'dart:io';
import 'package:discord/discord.dart';
import 'package:yaml/yaml.dart';

Client bot;
YamlMap config;

Map<String, int> last_message = new Map();
RegExp discord_link_regex = new RegExp(r'(discord\.gg\/[A-Za-z0-9]+|discordapp\.com\/invite\/[A-Za-z0-9]+)', caseSensitive: false);
RegExp link_regex = new RegExp(r'https?:\/\/(?:\S+\.|(?![\s]+))[^\s\.]+\.[^\s]{2,}|\S+\.[^\s]+\.[^\s]{2,}', caseSensitive: false);

main() async {
	config = loadYaml(await new File('config.yaml').readAsString());
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

	if (config['slow_mode']['enabled']) {
		int sent = m.timestamp.millisecondsSinceEpoch;
		if (last_message[m.author.id] != null && sent - last_message[m.author.id] < config['slow_mode']['time']) {
			m.delete();
			return;
		}

		last_message[m.author.id] = sent;
	}
}
