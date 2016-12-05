class ChannelConfig {
	List<String> mods;
	List<String> whitelist;
	Map slow_mode;
	Map caps_removal;
	Map<String, bool> block_links;
	List<String> blacklisted_words;
	Map mentions_spam;
	Map<String, bool> repeat_spam;
	Map welcome;

	RegExp caps_removal_regex;
	Map<String, int> last_message_time = new Map<String, int>();
	Map<String, String> last_message_text = new Map<String, String>();
	List<String> muted_users = new List<String>();

	ChannelConfig({this.mods, this.whitelist, this.slow_mode, this.caps_removal, this.block_links, this.blacklisted_words, this.mentions_spam, this.repeat_spam, this.welcome}) {
		if (this.caps_removal['enabled'] && this.caps_removal['threshold'] < 3)
			throw 'The caps block threshold must be at least 3';
		caps_removal_regex = new RegExp('[A-Z][A-Z ]{' + (this.caps_removal['threshold'] - 2).toString() + '}[A-Z]');

		if (!['delete', 'kick', 'ban'].contains(this.mentions_spam['action']))
			throw 'The mentions_spam action must be one of: delete, kick, ban';
	}

	void updateCapsSpamRegex(int threshold) {
		if (threshold < 1)
			this.caps_removal['enabled'] = false;
		else {
			this.caps_removal['enabled'] = true;
			this.caps_removal['threshold'] = threshold;
			this.caps_removal_regex = new RegExp('[A-Z][A-Z ]{' + (this.caps_removal['threshold'] - 2).toString() + '}[A-Z]');
		}
	}
}
