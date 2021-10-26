# Fixes Resync gem's XPath expression that determines capability attribute value of an XML document
module Resync
  module XMLParser
    CAPABILITY_ATTRIBUTE =
      "/*/*[namespace-uri() = 'http://www.openarchives.org/rs/terms/' and local-name() = 'md']/@capability".freeze
  end
end
