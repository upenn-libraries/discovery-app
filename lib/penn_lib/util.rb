
require 'zlib'

module PennLib

  module Util

    class << self

      # returns a file IO object, using a GzipReader wrapper if filename ends in .gz
      def openfile(path)
        if path.end_with?('.gz')
          Zlib::GzipReader.new(File.open(path), :external_encoding => 'UTF-8')
        else
          File.open(path)
        end
      end

    end

  end
end