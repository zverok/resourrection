# encoding: utf-8
require 'resourrection'

Sequel::Model.plugin(:schema)
Sequel::Model.plugin(:json_serializer)

require 'webmock'
require 'rack/test'
require 'json'

module Resourrection
    module SpecHelpers
        module RackMockResponseHelper
            def as_json
                success? or raise_error!
                @as_json ||= JSON.parse(body)
            end

            alias :json :as_json

            def success?
                (200..299) === status
            end

            def unauthorized?
                status == 401
            end

            def [](key)
                as_json[key]
            end

            def raise_error!
                raise(RuntimeError, "Error #{status}: #{body}")
            end
        end

        module WebMock
            module HashCounter
                def ordered_keys
                    @order.to_a.sort_by(&:last).map(&:first)
                end
            end

            module RequestSignature
                def json_body
                    JSON.parse(body)
                end
            end

            def requests
                ::WebMock::RequestRegistry.instance.requested_signatures.ordered_keys
            end

            def select_requests(pattern)
                requests.select{|r| r.uri.to_s[pattern]}
            end
        end

        module WebHelper
            include Rack::Test::Methods

            def post_json(url, data = {})
                post url, data.to_json, {'CONTENT_TYPE' => 'application/json'}
            end

            def put_json(url, data = {})
                put url, data.to_json, {'CONTENT_TYPE' => 'application/json'}
            end

            def patch_json(url, data = {})
                patch url, data.to_json, {'CONTENT_TYPE' => 'application/json'}
            end

            def post_json!(url, data = {})
                post_json(url, data)
                last_response.success? or last_response.raise_error!
            end

            def response_of_post(url, data = {})
                post_json url, data
                last_response
            end

            def response_of_put(url, data = {})
                put_json url, data
                last_response
            end

            def response_of_get(url, data = {})
                get url, data
                last_response
            end

            def response_of_delete(url, data = {})
                delete url, data
                last_response
            end

        end
    end
end

class Rack::MockResponse
    include Resourrection::SpecHelpers::RackMockResponseHelper
end

module WebMock
    extend Resourrection::SpecHelpers::WebMock

    class Util::HashCounter
        include Resourrection::SpecHelpers::WebMock::HashCounter
    end

    class RequestSignature
        include Resourrection::SpecHelpers::WebMock::RequestSignature
    end
end

RSpec::Matchers.define :be_successful do
    match do |response|
        response.success?
    end

    failure_message_for_should do |response|
        "expected HTTP success but got #{response.status}:\n" + response.body
    end

    failure_message_for_should_not do |response|
        "expected no HTTP success but got #{response.status}:\n" + response.body
    end
end


RSpec::Matchers.define :be_sorted_by_key do |key|
    match do |actual|
        @mapped = actual.map{|hash| hash[key]}
        @mapped.sort.should == @mapped
    end

    failure_message_for_should do |actual|
        "expected to be sorted by #{key}, in fact having #{@mapped.inspect}"
    end
end

RSpec::Matchers.define :be_reverse_sorted_by_key do |key|
    match do |actual|
        @mapped = actual.map{|hash| hash[key]}
        @mapped.sort.reverse.should == @mapped
    end

    failure_message_for_should do |actual|
        "expected to be reverse sorted by #{key}, in fact having #{@mapped.inspect}"
    end
end

RSpec.configure do |config|
    config.include(Resourrection::SpecHelpers::WebHelper)
end

