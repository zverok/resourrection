module Resourrection
    module HTTPMethodResponder
        def respond(method, route, params, response)
            @route, @params, @response = route, params, response
            response = send(method)
            @route, @params, @response = nil

            serialize(response)
        end

        def serialize(data)
            data.to_json
        end

        attr_reader :route, :params, :response
    end

    class Resource
        def initialize(model, id, params = {})
            @model = model
            @object = @model.find(params.merge(id: id)) or raise(Sinatra::NotFound)
        end

        attr_reader :model, :object

        # responding to HTTP methods
        def get
            object
        end

        def put
            to_set = params.symbolize_keys.only(*object.columns).except(:id)
            object.set(to_set)
            if object.valid?
                object.save
                object
            else
                response.status = 422
                {'errors' => object.error_texts}
            end
        end

        def patch
            to_set = params.symbolize_keys.only(*object.columns).except(:id)
            object.set(to_set)
            if object.valid?
                object.save
                object
            else
                response.status = 422
                {'errors' => object.error_texts}
            end
        end

        def delete
            object.destroy
            nil
        end

        include HTTPMethodResponder

        # nesting
        def get_nested_collection(association_name)
            association = model.association_reflection(association_name)
            ResourceCollection.new(association[:class], association[:class].filter(association[:key] => object.id), association[:key] => object.id)
        end

        def get_nested_resource(association_name, id)
            association = model.association_reflection(association_name)
            Resource.new(association[:class], id, association[:key] => object.id)
        end
    end

    class ResourceCollection
        def initialize(model, dataset = model.dataset, additional_params = {})
            @model, @dataset = model, dataset
            @additional_params = additional_params # FIXME: ugly
        end

        attr_reader :model, :dataset

        # responding to HTTP methods
        def get
            processed_dataset = route.features.inject(dataset){|ds, f| f.process_dataset(ds, params)}
            result = processed_dataset.all
            route.features.inject(result){|res, f| f.process_output(processed_dataset, res, params)}
        end
        
        def post
            response.status = 201
            to_set = params.symbolize_keys.only(*model.columns).merge(@additional_params)
            model.create(to_set)
        end

        include HTTPMethodResponder
    end
end
