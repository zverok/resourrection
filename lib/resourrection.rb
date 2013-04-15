require 'rubygems'
require 'sinatra'
require 'sequel'

require 'resourrection/core_ext'
require 'resourrection/request_body_parser'
require 'resourrection/resources'
require 'resourrection/routes'

module Resourrection
    def resourrections; @resourrections ||= [] end

    def resourrect(*arg, &block)
        resourrections << ResourceRoute.new(self, *arg, &block)
    end

    def self.registered(app)
        app.send :use, RequestBodyParser
    end
end

Sinatra.register Resourrection
