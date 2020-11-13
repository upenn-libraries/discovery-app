# frozen_string_literal: true

header = '<?xml version="1.0" encoding="UTF-8"?>'+"\n"
open_tag = '<urlset xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd" xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+"\n"
close_element = '</loc></url>'+"\n"

return @access_list.each_with_object(header + open_tag) do |(id), str|
  str << '<url><loc>'+sitemap_url(id, format: :xml)+close_element
end + '</urlset>'
