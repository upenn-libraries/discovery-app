var pennFeedReader = (function($) {

	// max # of characters to show in {description} (default 200)
	var maxCharacters = 200;

	// include line breaks in {description} (default true)
	var lineBreaks = true;

	// define our custom tokens
	var customTokens = {
		// {description}: shows the beginning of the plain text of the feed item, up to
		// the number of characters defined in feedOptions['maxCharacters'] (or 200 by default)
		description: function(entry, tokens) {

			// get first <maxCharacters> characters of the plain text
			var description = tokens.bodyPlain.substring(0, maxCharacters);
			
			// end on a word
			description = description.substring(0, description.lastIndexOf(' '));
			if (lineBreaks) {
				description = description.replace(/(\n+)/g, '<br /><br />');
			}
	        	  
	        // wrap content
	        return '<div class="itemdesc"><content>' + description + '...</content></div>';
		}
	};

	return {
		getFeed: function(destination, feedURL, feedOptions, callback) {

			// enable multiple destinations
			if ($(destination).length > 1) {
				$(destination).each(function() {
					pennFeedReader.getFeed(this, feedURL, feedOptions, callback);
				});
				return;
			}

			// add our custom tokens
			if (feedOptions == null) feedOptions = {};
			if (!feedOptions.hasOwnProperty('tokens')) feedOptions.tokens = {};
			for (var token in customTokens) {
				if (customTokens.hasOwnProperty(token)) {
					feedOptions.tokens[token] = customTokens[token];
				}
			}

			// set max # of characters for the {description} custom token
			if (feedOptions.hasOwnProperty('maxCharacters')) maxCharacters = feedOptions['maxCharacters'];
			if (feedOptions.hasOwnProperty('lineBreaks')) lineBreaks = feedOptions['lineBreaks'];

			// If a custom date formatting function hasn't been specified, add a default one.
			// (We always define a custom formatting function so that we don't have to use moment.js)
			if (!feedOptions.hasOwnProperty('dateFormatFunction')) {
				feedOptions.dateFormatFunction = function(date) {
					//console.log(new Date(date).toDateString());
					return new Date(date).toDateString();
				};
			}

			// call jquery.rss.js
			$(destination).rss(feedURL, feedOptions, callback);
		}
	};

})(jQuery);