class ChannelConfig {
	List<String> mods;
	List<String> whitelist;
	Map slow_mode;
	Map caps_spam;
	Map<String, bool> block_links;
	List<String> blacklisted_words;
	RegExp caps_spam_regex;
	Map mentions_spam;
	Map<String, bool> repeat_spam;

	ChannelConfig({this.mods, this.whitelist, this.slow_mode, this.caps_spam, this.block_links, this.blacklisted_words, this.mentions_spam, this.repeat_spam}) {
		if (this.caps_spam['enabled'] && this.caps_spam['threshold'] < 3)
			throw 'The caps block threshold must be at least 3';
		caps_spam_regex = new RegExp('[A-Z][A-Z ]{' + (this.caps_spam['threshold'] - 2).toString() + '}[A-Z]');

		if (!['delete', 'kick', 'ban'].contains(this.mentions_spam['action']))
			throw 'The mentions_block action must be one of: delete, kick, ban';
	}
}
