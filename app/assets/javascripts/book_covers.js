
$(document).ready(function() {
  exclude_gb = 0;
  try_gb = 0;
  found_gb = 0;

  by_id = {};
  $('#documents > .document').each(function(idx) {
    doc = $(this)
    page_idx = doc.attr('data-document-counter');
    cover_div = doc.find('div.cover-image');
    if (cover_div.children('img').length > 0) {
      exclude_gb++;
    } else {
      try_gb++;
      isbns = cover_div.attr('data-isbns');
      if (isbns) {
        // NOTE: multiple isbns may be associated with the same record.
	// We check all of them and prioritize results at img display
	// time.
        isbns.split(',').forEach(function(isbn) {
          key = "isbn:" + isbn;
	  // NOTE: multiple page_idx (divs) may be associated with the
	  // same ids, so we have to support multi-value mappings
	  (by_id[key] || (by_id[key] = [])).push({
	    "page_idx": page_idx,
	    "cover_div": cover_div
	  });
	});
      }
      oclc_id = cover_div.attr('data-oclc');
      if (oclc_id) {
        key = "oclc:" + oclc_id;
	// see above wrt multi-value mappings
	(by_id[key] || (by_id[key] = [])).push({
	  "page_idx": page_idx,
	  "cover_div": cover_div
	});
      }
    }
  });

  gb_base_url = "https://books.google.com/books?callback=?&jscmd=viewapi&bibkeys=";

  // naturally dedupes id keys
  url = gb_base_url + encodeURIComponent(Object.keys(by_id).join(","));

  // now we accumulate response entries, keyed by page element
  by_element = {};
  $.getJSON(url).done(function(rsp) {
    Object.keys(rsp).forEach(function(id) {
      thumb = rsp[id]["thumbnail_url"];
      if (thumb) {
	modified_thumb = thumb.replace(/zoom=./,"zoom=1").replace("&edge=curl","");
	element_structs = by_id[id];
	element_structs.forEach(function(element_struct) {
	  page_idx = element_struct["page_idx"];
	  by_element_struct = by_element[page_idx] || (by_element[page_idx] = {
	    "cover_div": element_struct["cover_div"],
	    "thumbs": {}
	  });
	  by_element_struct["thumbs"][id] = modified_thumb;
	});
      }
    });

    // Final pass, iterate over response per page element and insert the img tags
    Object.keys(by_element).forEach(function(page_idx) {
      found_gb++;
      element_struct = by_element[page_idx];
      thumbs = element_struct["thumbs"];

      // predictable priority order if different ids return different cover img urls
      min = 'zzzz';
      Object.keys(thumbs).forEach(function(id) {
        if (id < min) {
	  min = id;
	}
      });
      img_tag = "<img alt='' src='" + thumbs[min] + "'>"
      element_struct["cover_div"].append(img_tag);
    });
    // console.log("exclude_gb=" + exclude_gb + "; try_gb=" + try_gb + "; found_gb=" + found_gb);
  });
});
