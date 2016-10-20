class ChannelConfig {
	List<String> whitelist;
	Map slow_mode;
	Map caps_block;
	Map<String, bool> links_block;
	List<String> blacklisted_words;
	RegExp caps_block_regex;
	Map mentions_block;

	ChannelConfig({this.whitelist, this.slow_mode, this.caps_block, this.links_block, this.blacklisted_words, this.mentions_block}) {
		if (this.caps_block['enabled'] && this.caps_block['threshold'] < 3)
			throw 'The caps block threshold must be at least 3';
		caps_block_regex = new RegExp('[A-Z][A-Z ]{' + (this.caps_block['threshold'] - 2).toString() + '}[A-Z]');

		if (!['delete', 'kick', 'ban'].contains(this.mentions_block['action']))
			throw 'The mentions_block action must be one of: delete, kick, ban';
	}
}
