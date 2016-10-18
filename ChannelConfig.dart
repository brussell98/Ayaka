class ChannelConfig {
	List<String> whitelist;
	Map slow_mode;
	Map caps_block;
	Map<String, bool> links_block;
	List<String> blacklisted_words;
	RegExp caps_block_regex;

	ChannelConfig({this.whitelist, this.slow_mode, this.caps_block, this.links_block, this.blacklisted_words}) {
		/*
		this.whitelist = new List.from(c['whitelist']);
		this.slow_mode = new Map.from(c['slow_mode']);
		this.caps_block = new Map.from(c['caps_block']);
		this.links_block = new Map.from(c['links_block']);
		this.blacklisted_words = new List.from(c['blacklisted_words']);
		*/

		if (this.caps_block['enabled'] && this.caps_block['threshold'] < 3)
			throw 'The caps block threshold must be at least 3';
		caps_block_regex = new RegExp('[A-Z][A-Z ]{' + (this.caps_block['threshold'] - 2).toString() + '}[A-Z]');
	}
}
