$(document).ready(function() {
    pennFeedReader.getFeed(	".collection-news",
        "https://pennlibnews.wordpress.com/category/collection-news/feed/",
        {
            outputMode: 'json_xml',
            limit: '3',
            maxCharacters: '150',
            lineBreaks: false,
            layoutTemplate: '<div class="feed-container">{entries}</div>',
            entryTemplate: '<div class="feed-item"><div class="item-title"><a target="_new" href="{url}">{title}</a></div>{description}<span>Posted: {date}</span></div>',
            dateFormatFunction: function(date) {
                // MMM DD format
                var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                var jsDate = new Date(date);
                var day = jsDate.getDate();
                if (day < 10) {
                    day = "0" + day;
                }
                return months[jsDate.getMonth()] + " " + day;
            }
        });
});
