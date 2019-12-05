
require 'net/http'
require 'singleton'

class CollectionNewsController < ApplicationController

  include RssProxy

  def index
    rss_proxy('http://www.library.upenn.edu/blogs/libraries-news/category/Collections/rss.xml')
  end

end
