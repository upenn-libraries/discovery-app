module PennLib
  module JsonFacet

class Config

  def initialize(json_facet_spec, static_options = nil)
    @options = static_options
    if json_facet_spec.respond_to?(:lambda?) && json_facet_spec.lambda?
      @json_facet_lambda = json_facet_spec
    else
      @json_facet_spec = json_facet_spec
    end
  end

  def get_json_facet_request(key, field, limit, offset, sort, prefix, condition)
    if @json_facet_lambda
      resolved = @json_facet_lambda.call(field, limit, offset, sort, prefix)
      if resolved.is_a?(Array)
        request_hash, options = resolved
      else
        request_hash = resolved
        options = @options
      end
    else
      request_hash = @json_facet_spec
      options = @options
    end
    if request_hash && (options.nil? || condition.call(options[:if], options[:unless]))
      return { request: RequestStruct.new(key, request_hash, options) }
    else
      fallback = options&.[](:fallback)
      return fallback.nil? ? nil : { fallback: fallback }
    end
  end
end

class RequestStruct

  attr_reader :key, :request_hash, :options

  def initialize(key, request_hash, options)
    @key = key
    @request_hash = {
      @key.to_sym => request_hash
    }
    @options = options
  end

  def to_s
    @request_hash.to_json({ except: :blacklight_options })
  end
end
end
end
