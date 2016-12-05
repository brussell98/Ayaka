import 'package:discord/discord.dart';
import 'package:discord/discord_vm.dart';
import 'package:toml/loader/fs.dart';
import 'ChannelConfig.dart';

Client bot;
String commandPrefix;
Map<String, Function> commands = new Map<String, Function>();
Map<String, ChannelConfig> channelConfig = new Map<String, ChannelConfig>();
Map<String, int> last_message_time = new Map<String, int>();
Map<String, String> last_message_text = new Map<String, String>();
final RegExp discord_link_regex = new RegExp(r'discord(\.gg|app\.com\/invite|\.me)\/[A-Za-z0-9\-]+', caseSensitive: false);
final RegExp link_regex = new RegExp(r'<?(https?:\/\/(?:\S+\.|(?![\s]+))[^\s\.]+\.\S{2,}|\S+\.\S+\.\S{2,})>?', caseSensitive: false);

main() async {
	FilesystemConfigLoader.use();
	var config = await loadConfig();

	for (dynamic node in config.keys) {
		if (node != 'global')
			channelConfig[node.toString()] = new ChannelConfig(
				mods: new List<String>.from(config[node]['mods'] ?? config['global']['mods']),
				whitelist: new List<String>.from(config[node]['whitelist'] ?? config['global']['whitelist']),
				slow_mode: new Map.from(config[node]['slow_mode'] ?? config['global']['slow_mode']),
				caps_removal: new Map.from(config[node]['caps_removal'] ?? config['global']['caps_removal']),
				block_links: new Map<String, bool>.from(config[node]['block_links'] ?? config['global']['block_links']),
				blacklisted_words: new List<String>.from(config[node]['blacklisted_words'] ?? config['global']['blacklisted_words']),
				mentions_spam: new Map.from(config[node]['mentions_spam'] ?? config['global']['mentions_spam']),
				repeat_spam: new Map<String, bool>.from(config[node]['repeat_spam'] ?? config['global']['repeat_spam']),
				welcome: new Map.from(config[node]['welcome'] ?? {'enabled': false})
			);
	}

	commandPrefix = config['global']['prefix'];
	registerCommands();
	configureDiscordForVM();
	bot = new Client(config['global']['token'], new ClientOptions(disableEveryone: true, messageCacheSize: 5, forceFetchMembers: false));

	bot.onReady.listen(onReady);
	bot.onMessage.listen(onMessage);
	bot.onMessageUpdate.listen(onMessageUpdate);
	bot.onGuildMemberAdd.listen(onGuildMemberAdd);
}

onReady(ReadyEvent e) {
	print('Ayaka is online!');
}

onGuildMemberAdd(GuildMemberAddEvent e) {
	channelConfig.forEach((id, config) {
		if (config.welcome['enabled'] && e.member.guild.channels.containsKey(id)) {
			Map replacers = {'user': e.member.username, 'server': e.member.guild.name, 'mention': e.member.mention};
			bot.channels[id].sendMessage(config.welcome['message'].replaceAllMapped(
				new RegExp(r"\{(user|server|mention)\}", caseSensitive: false),
				(Match m) => replacers[m[1]]
			));
		}
	});
}

onMessage(MessageEvent e) {
	if (e.message.channel is DMChannel || !channelConfig.containsKey(e.message.channel.id))
		return null;

	Message m = e.message;

	if (m.content.startsWith(commandPrefix) && channelConfig[m.channel.id].mods.contains(m.author.id))
		return handlePossibleCommand(m);

	if (channelConfig[m.channel.id].mods.contains(m.author.id) || channelConfig[m.channel.id].whitelist.contains(m.author.id))
		return null;

	if (channelConfig[m.channel.id].muted_users.length != 0 && channelConfig[m.channel.id].muted_users.contains(m.author.id))
		return m.delete().catchError(onError);

	checkMessage(m, false);
}

onMessageUpdate(MessageUpdateEvent e) {
	if (e.newMessage.channel is DMChannel || !channelConfig.containsKey(e.newMessage.channel.id))
		return null;

	Message m = e.newMessage;

	if (channelConfig[m.channel.id].whitelist.contains(m.author.id))
		return null;

	checkMessage(m, true);
}

checkMessage(Message m, bool update) {
	if (channelConfig[m.channel.id].mentions_spam['enabled']) {
		if (m.mentions.length >= channelConfig[m.channel.id].mentions_spam['threshold']) {
			switch (channelConfig[m.channel.id].mentions_spam['action']) {
				case 'kick':
					m.member.kick().catchError(onError);
					m.delete().catchError(onError);
					print('User kicked for mention spam: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
					break;
				case 'ban':
					m.member.ban().catchError(onError);
					m.delete().catchError(onError);
					print('User banned for mention spam: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
					break;
				default:
					m.delete().catchError(onError);
					print('Message deleted for mention spam: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
			}
		}
	}

	if (update == false && channelConfig[m.channel.id].slow_mode['enabled']) {
		int sent = m.timestamp.millisecondsSinceEpoch;
		if (channelConfig[m.channel.id].last_message_time[m.author.id] != null && sent - channelConfig[m.channel.id].last_message_time[m.author.id] < channelConfig[m.channel.id].slow_mode['time']) {
			print('Message deleted from ${m.author.username} (${m.author.id}) because of slow mode');
			return m.delete().catchError(onError);
		}
		channelConfig[m.channel.id].last_message_time[m.author.id] = sent;
	}

	if (update == false && channelConfig[m.channel.id].repeat_spam['enabled']) {
		String text = channelConfig[m.channel.id].repeat_spam['ignore_case'] ? m.content.toLowerCase() : m.content;
		if (channelConfig[m.channel.id].last_message_text[m.author.id] != null && channelConfig[m.channel.id].last_message_text[m.author.id] == text) {
			print('Message deleted from ${m.author.username} (${m.author.id}) because of repeat message');
			return m.delete().catchError(onError);
		}
		channelConfig[m.channel.id].last_message_text[m.author.id] = text;
	}

	if (channelConfig[m.channel.id].block_links['enabled']) {
		if (discord_link_regex.hasMatch(m.content)) {
			print('Message deleted for containing link: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
			return m.delete().catchError(onError);
		}

		if (!channelConfig[m.channel.id].block_links['invites_only']) {
			String link = link_regex.stringMatch(m.content);
			if (link != null) {
				if (!channelConfig[m.channel.id].block_links['allow_non_embed'] || (!link.startsWith('<') && !link.endsWith('>'))) {
					print('Message deleted for containing link: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
					return m.delete().catchError(onError);
				}
			}
		}
	}

	if (channelConfig[m.channel.id].blacklisted_words.length != 0) {
		String lower = m.content.toLowerCase();
		for (String word in channelConfig[m.channel.id].blacklisted_words) {
			if (lower.contains(word)) {
				print("Message deleted for containing blacklisted word '$word': ${m.author.username} (${m.author.id})\nMessage: ${m.content}");
				return m.delete().catchError(onError);
			}
		}
	}

	if (channelConfig[m.channel.id].caps_removal['enabled']) {
		if (channelConfig[m.channel.id].caps_removal_regex.hasMatch(m.content)) {
			print('Message deleted for containing too many caps: ${m.author.username} (${m.author.id})\nMessage: ${m.content}');
			return m.delete().catchError(onError);
		}
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

	commands['whitelist'] = (Message m, String args) async {
		if (m.mentions.length > 0) {
			List<String> users_added = new List<String>();
			await m.mentions.forEach((String id, User user) {
				channelConfig[m.channel.id].whitelist.add(id);
				users_added.add(user.username);
			});
			m.channel.sendMessage('Whitelisted: ${users_added.join(', ')}');
			print('Whitelisted: ${users_added.join(', ')}');
		} else
			m.channel.sendMessage('Mention the users you want to whitelist');
	};

	commands['unwhitelist'] = (Message m, String args) async {
		if (m.mentions.length > 0) {
			List<String> users_removed = new List<String>();
			await m.mentions.forEach((String id, User user) {
				channelConfig[m.channel.id].whitelist.remove(id);
				users_removed.add(user.username);
			});
			m.channel.sendMessage('Removed from whitelisted: ${users_removed.join(', ')}');
			print('Removed from whitelisted: ${users_removed.join(', ')}');
		} else
			m.channel.sendMessage('Mention the users you want to remove from the whitelist');
	};

	commands['mod'] = (Message m, String args) async {
		if (m.mentions.length > 0) {
			List<String> users_added = new List<String>();
			await m.mentions.forEach((String id, User user) {
				channelConfig[m.channel.id].mods.add(id);
				users_added.add(user.username);
			});
			m.channel.sendMessage('Modded: ${users_added.join(', ')}');
			print('Modded: ${users_added.join(', ')}');
		} else
			m.channel.sendMessage('Mention the users you want to mod');
	};

	commands['unmod'] = (Message m, String args) async {
		if (m.mentions.length > 0) {
			List<String> users_removed = new List<String>();
			await m.mentions.forEach((String id, User user) {
				channelConfig[m.channel.id].mods.remove(id);
				users_removed.add(user.username);
			});
			m.channel.sendMessage('Removed from mods: ${users_removed.join(', ')}');
			print('Removed from mods: ${users_removed.join(', ')}');
		} else
			m.channel.sendMessage('Mention the users you want to remove from the unmod');
	};

	commands['caps removal'] = (Message m, String args) {
		switch (args.toLowerCase()) {
			case 'enable':
			case 'on':
				channelConfig[m.channel.id].caps_removal['enabled'] = true;
				break;
			case 'disable':
			case 'off':
				channelConfig[m.channel.id].caps_removal['enabled'] = false;
				break;
			default:
				try {
					int threshold = int.parse(args);
					channelConfig[m.channel.id].updateCapsSpamRegex(threshold);
				} catch(error) {
					m.channel.sendMessage('Invalid threshold');
				}
		};
	};

	commands['mute'] = (Message m, String args) async {
		if (m.mentions.length > 0) {
			List<String> users_muted = new List<String>();
			await m.mentions.forEach((String id, User user) {
				channelConfig[m.channel.id].muted_users.add(id);
				users_muted.add(user.username);
			});
			m.channel.sendMessage('Muted: ${users_muted.join(', ')}');
			print('Muted: ${users_muted.join(', ')}');
		} else
			m.channel.sendMessage('Mention the users you want to mute');
	};

	commands['unmute'] = (Message m, String args) async {
		if (m.mentions.length > 0) {
			List<String> users_unmuted = new List<String>();
			await m.mentions.forEach((String id, User user) {
				channelConfig[m.channel.id].muted_users.remove(id);
				users_unmuted.add(user.username);
			});
			m.channel.sendMessage('Unmuted: ${users_unmuted.join(', ')}');
			print('Unmuted: ${users_unmuted.join(', ')}');
		} else
			m.channel.sendMessage('Mention the users you want to unmute');
	};

	final RegExp embeds_option_parser = new RegExp(r'allow non(?:-| )embeds?');
	commands['block links'] = (Message m, String args) {
		switch (args.toLowerCase()) {
			case 'disable':
			case 'off':
				channelConfig[m.channel.id].block_links['enabled'] = false;
				break;
			default:
				channelConfig[m.channel.id].block_links['enabled'] = true;
				channelConfig[m.channel.id].block_links['invites_only'] = args.toLowerCase().contains('invites only');
				channelConfig[m.channel.id].block_links['allow_non_embed'] = args.toLowerCase().contains(embeds_option_parser);
		};
	};

	final RegExp mentions_threshold_parser = new RegExp(r'\d+');
	final RegExp mentions_action_parser = new RegExp(r'delete|kick|ban', caseSensitive: false);
	commands['mentions spam'] = commands['mention spam'] = (Message m, String args) {
		switch (args.toLowerCase()) {
			case 'enable':
			case 'on':
				channelConfig[m.channel.id].mentions_spam['enabled'] = true;
				break;
			case 'disable':
			case 'off':
				channelConfig[m.channel.id].mentions_spam['enabled'] = false;
				break;
			default:
				channelConfig[m.channel.id].mentions_spam['enabled'] = true;
				try {
					String threshold = mentions_threshold_parser.stringMatch(args);
					if (threshold != null)
						channelConfig[m.channel.id].mentions_spam['threshold'] = int.parse(args);
				} catch(error) {
					print(error);
				}
				String action = mentions_action_parser.stringMatch(args);
				if (action != null)
					channelConfig[m.channel.id].mentions_spam['action'] = action;
		};
	};

	commands['repeat spam'] = (Message m, String args) {
		switch (args.toLowerCase()) {
			case 'disable':
			case 'off':
				channelConfig[m.channel.id].repeat_spam['enabled'] = false;
				break;
			default:
				channelConfig[m.channel.id].repeat_spam['enabled'] = true;
				channelConfig[m.channel.id].repeat_spam['ignore_case'] = args.toLowerCase().contains('ignore case');
		};
	};

	commands['welcome'] = (Message m, String args) {
		switch (args.toLowerCase()) {
			case 'disable':
			case 'off':
				channelConfig[m.channel.id].welcome['enabled'] = false;
				break;
			default:
				channelConfig[m.channel.id].welcome['enabled'] = true;
				channelConfig[m.channel.id].welcome['message'] = args;
		};
	};
}

handlePossibleCommand(Message m) {
	String command = m.content.substring(1);
	for (String key in commands.keys) {
		if (command.startsWith(key)) {
			print('Command Detected from ${m.author.username}: $key');
			return commands[key](m, command.substring(key.length + 1));
		}
	}
}

onError(dynamic error) {
	print(error);
}
