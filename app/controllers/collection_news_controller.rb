
require 'net/http'
require 'singleton'

class CollectionNewsController < ApplicationController

  include RssProxy

  def index
    rss_proxy('https://pennlibnews.wordpress.com/category/collection-news/feed/')
  end

end
