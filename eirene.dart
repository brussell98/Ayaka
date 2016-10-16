import 'dart:io';
import 'package:discord/discord.dart' as discord;
import 'package:yaml/yaml.dart';

discord.Client bot;
Map<String, String> config;

main() async {
	config = loadYaml(await new File('config.yaml').readAsString());
	bot = new discord.Client(config['token'], new discord.ClientOptions(disableEveryone: true, messageCacheSize: 5, forceFetchMembers: false));

	bot.onReady.listen(onReady);
	bot.onMessage.listen(onMessage);
}

onReady(discord.ReadyEvent e) {
	print('Eirene is online!');
}

onMessage(discord.MessageEvent e) {
	if (e.message.channel is discord.DMChannel)
		return;

	discord.Message m = e.message;
	print('[${new DateTime.now().toString()}] ${m.guild.name} > ${m.channel.name} > ${m.author.username}: ${m.content}');

	if (m.content == '!test')
		m.channel.sendMessage('It worked');
}
