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
                    route.make_resource(id).respond(method, route, params, response)
                }
            end

            [:get, :post].each do |method|
                app.send(method, collection_url){
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

        #def ordered(*arg)
            #features << Ordered.new(*arg)
        #end
    end

    class RouteFeature
        def process_dataset(dataset, params)
            dataset
        end

        def process_output(dataset, output, params)
            output
        end
    end

    # route features
    class Paged < RouteFeature
        def initialize(page_param_name, pagesize_param_name, options = {})
            @page_param_name, @pagesize_param_name = page_param_name, pagesize_param_name
            @default = options.delete(:default)
        end
        
        def process_dataset(dataset, params)
            page, pagesize = process_params(params)
            dataset.limit(page*pagesize, pagesize)
        end

        def process_output(dataset, output, params)
            page, pagesize = process_params(params)

            {
                'content' => output,
                'pager' => {
                    'page' => page,
                    'next' => page+1,
                    'total' => (dataset.unlimited.count / pagesize.to_f).ceil
                }
            }
        end

        def process_params(params)
            page = params.delete(@page_param_name) || 1
            pagesize = params.delete(@pagesize_param_name) || @default or
                raise(ArgumentError, "No pagesize param provided")

            [page.to_i, pagesize.to_i]
        end
    end

    class NestedResourceRoute < ResourceRoute
        def initialize(app, base, name, options={}, &block)
            @base = base
            @association = options.delete(:association) || name.to_sym
            super(app, name, options, &block)
        end

        attr_reader :base, :association

        protected

        def setup_routes!
            route, association, base = self, @association, @base
            [:get, :put, :patch, :delete].each do |method|
                app.send(method, url){|*arg|
                    base.make_resource(*arg[0..-2]).
                        get_nested_resource(association, arg.last).
                        respond(method, route, params, response)
                }
            end

            [:get, :post].each do |method|
                app.send(method, collection_url){|*arg|
                    base.make_resource(*arg).
                        get_nested_collection(association).
                        respond(method, route, params, response)
                }
            end
        end

        def base_url
            "#{base.base_url}/(.+)/#{name}"
        end

        def url
            %r{#{base_url}/(.+).json}
        end

        def collection_url
            %r{#{base_url}.json}
        end
    end
end
