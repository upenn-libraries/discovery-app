# frozen_string_literal: true

header = '<?xml version="1.0" encoding="UTF-8"?>'+"\n"
open_tag = '<urlset xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd" xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+"\n"
close_element = '</lastmod></url>'+"\n"

return @solr_response['response']['docs'].each_with_object(header + open_tag) do |(doc), str|
  str << '<url><loc>'+solr_document_url(doc['id'])+'</loc><lastmod>'+Time.at(doc['last_update_isort']).strftime('%Y-%m-%dT%H:%M:%S%:z')+close_element
end + '</urlset>'
