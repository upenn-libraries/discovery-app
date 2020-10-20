module PennLib
  module JsonFacet

class Config

  def initialize(json_facet_spec, static_display_options = nil)
    @display_options = static_display_options
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
        request_hash, display_options = resolved
      else
        request_hash = resolved
        display_options = @display_options
      end
    else
      request_hash = @json_facet_spec
      display_options = @display_options
    end
    return nil if request_hash.nil? || (display_options && !condition.call(display_options))
    RequestStruct.new(key, request_hash, display_options)
  end
end

class RequestStruct

  attr_accessor :key, :request_hash, :display_options

  def initialize(key, request_hash, display_options)
    @key = key
    @request_hash = {
      @key.to_sym => request_hash
    }
    @display_options = display_options
  end

  def to_s
    @request_hash.to_json
  end
end
end
end
