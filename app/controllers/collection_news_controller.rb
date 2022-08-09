# frozen_string_literal: true

require 'singleton'

class CollectionNewsController < ApplicationController
  include RssProxy

  PENN_LIB_NEWS_RSS_URL =
    'https://old.library.upenn.edu/blogs/libraries-news/category/Collections/rss.xml'

  def index
    rss_proxy PENN_LIB_NEWS_RSS_URL
  end
end
