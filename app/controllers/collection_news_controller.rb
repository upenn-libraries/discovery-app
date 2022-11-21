# frozen_string_literal: true

require 'singleton'

class CollectionNewsController < ApplicationController
  include RssProxy

  PENN_LIB_NEWS_RSS_URL =
    'https://www.library.upenn.edu/penn-libraries-news/collections/rss.xml'

  def index
    rss_proxy PENN_LIB_NEWS_RSS_URL
  end
end
