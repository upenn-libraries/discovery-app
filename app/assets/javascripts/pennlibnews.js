$(document).ready(function() {

    function formatDate(dateStr) {
        var monthNames = [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ];
        var d = new Date(dateStr);
        return monthNames[d.getMonth()] + " " + d.getDate();
    }

    function truncate(s, maxCharacters, lineBreaks) {
        return [ s ].filter(function (s) {
            return s != null;
        }).map(function (s) {
            if(s.length > maxCharacters) {
                var trunc = s.substring(0, maxCharacters);
                return trunc.substring(0, trunc.lastIndexOf(' ')) + "...";
            }
            return s;
        }).map(function (s) {
            return lineBreaks ? s.replace(/(\n+)/g, '<br /><br />') : s;
        })[0];
    }

    function getFeed(selector, optionsArg) {
        var defaultOptions = {
            maxItems: 3,
            maxCharacters: 150,
            lineBreaks: false
        };
        var options = $.extend({}, defaultOptions, optionsArg || {});

        $.ajax("/collection_news", {
            dataType: "xml",
            success: function (data) {
                var container = $('<div>', { class: "feed-container" });

                $(data).find("item").slice(0, options.maxItems).each(function(idx, element) {
                    var title = $(element).find("title").first().text();
                    var url = $(element).find("link").first().text();
                    var desc = truncate($(element).find("description").first().text(), options.maxCharacters, options.lineBreaks);
                    var date = formatDate($(element).find("pubDate").first().text());

                    var item = $('<div>', { class: "feed-item" });
                    var itemTitle = $('<div>', { class: "item-title" });
                    var itemLink = $('<a>', { target: "_new", href: url, text: title });
                    var itemDesc = $('<div>', { class: "itemdesc" });
                    var itemDescContent = $('<content>');
                    var itemPosted = $('<span>', { text: "Posted: " + date });

                    $(itemDescContent).html(desc);
                    $(itemDesc).append(itemDescContent);
                    $(itemTitle).append(itemLink);
                    item.append(itemTitle);
                    item.append(itemDesc);
                    item.append(itemPosted);

                    container.append(item);
                }).get();

                $(selector).append(container);
            }
        });
    }

    if($(".collection-news").size() > 0) {
        getFeed(".collection-news");
    }
});
