module Resourrection
    class ResourceRoute
        def initialize(app, name, options={}, &block)
            @app, @name = app, name
            @model = options.delete(:model)
            @features = []

            setup_routes!

            block and instance_eval(&block)
        end

        attr_reader :app, :name, :model, :features

        def base_url
            "/#{name}"
        end

        def url
            "#{base_url}/:id.json"
        end

        def collection_url
            "#{base_url}.json"
        end

        def make_resource(id)
            Resource.new(model, id)
        end

        protected

        def setup_routes!
            route, model = self, @model
            [:get, :put, :patch, :delete].each do |method|
                app.send(method, url){|id|
                    content_type 'application/json'
                    route.make_resource(id).respond(method, route, params, response)
                }
            end

            [:get, :post].each do |method|
                app.send(method, collection_url){
                    content_type 'application/json'
                    ResourceCollection.new(model).respond(method, route, params, response)
                }
            end
        end

        private

        # called from instance_eval'ed block in constructor
        # provides resource nesting
        def resourrect(*arg, &block)
            NestedResourceRoute.new(app, self, *arg, &block)
        end

        # called from instance_eval'ed block in constructor
        # provides several resource collection features
        def paged(*arg)
            features << Paged.new(*arg)
        end

        def ordered(*arg)
            features << Ordered.new(*arg)
        end

        def filtered(*arg, &block)
            features << Filtered.new(*arg, &block)
        end
    end

    class NestedResourceRoute < ResourceRoute
        def initialize(app, base, name, options={}, &block)
            @base = base
            @association = options.delete(:association) || name.to_sym
            super(app, name, options, &block)
        end

        attr_reader :base, :association

        def make_resource(*arg)
            base.make_resource(*arg[0..-2]).
                get_nested_resource(association, arg.last)
        end

        protected

        def setup_routes!
            route, association, base = self, @association, @base
            [:get, :put, :patch, :delete].each do |method|
                app.send(method, url){|*arg|
                    content_type 'application/json'
                    route.make_resource(*arg).
                        respond(method, route, params, response)
                }
            end

            [:get, :post].each do |method|
                app.send(method, collection_url){|*arg|
                    content_type 'application/json'
                    base.make_resource(*arg).
                        get_nested_collection(association).
                        respond(method, route, params, response)
                }
            end
        end

        def base_url
            "#{base.base_url}/(\\d+)/#{name}"
        end

        def url
            %r{#{base_url}/(\d+).json}
        end

        def collection_url
            %r{#{base_url}.json}
        end
    end
end
