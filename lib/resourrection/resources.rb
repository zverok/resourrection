require 'sequel/extensions/inflector' # Require for #singularize method

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
        def initialize(model, id, dataset = model.dataset, params = {})
            @model = model
            @base = params.delete(:base)
            @object = dataset.where(id: id).first or raise(Sinatra::NotFound)
        end

        attr_reader :model, :object

        # responding to HTTP methods
        def get
            object
        end

        def put
            data = params[route.name.singularize]
            data and data.kind_of?(Hash) or raise(ArgumentError, "Can't put resource from #{data.inspect}")
            to_set = data.symbolize_keys
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
            data = params[route.name.singularize]
            data and data.kind_of?(Hash) or raise(ArgumentError, "Can't patch resource from #{data.inspect}")
            to_set = data.symbolize_keys
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
            association = model.association_reflection(association_name) or
                raise(RuntimeError, "Association not found: #{model}/#{association_name}")

            key = association[:key] || association[:cache][:key]

            object.respond_to?(:"#{association_name}_dataset") or
                raise(RuntimeError, "#{object.inspect} seems not to have #{association_name}_dataset association method")
            dataset = object.send(:"#{association_name}_dataset")

            ResourceCollection.new(dataset.model, dataset, key => object.id, :base => object)
        end

        def get_nested_resource(association_name, id)
            association = model.association_reflection(association_name) or
                raise(RuntimeError, "Association not found: #{model}/#{association_name}")

            key = association[:key] || association[:cache][:key]

            object.respond_to?(:"#{association_name}_dataset") or
                raise(RuntimeError, "#{object.inspect} seems not to have #{association_name}_dataset association method")
            dataset = object.send(:"#{association_name}_dataset")

            Resource.new(dataset.model, id, dataset, base: object)
        end
    end

    class ResourceCollection
        def initialize(model, dataset = model.dataset, params = {})
            @model, @dataset = model, dataset
            @base = params.delete(:base)
            @additional_params = params # FIXME: ugly
        end

        attr_reader :model, :dataset

        # responding to HTTP methods
        def get
            processed_dataset = route.features.inject(dataset){|ds, f| f.process_dataset(ds, params)}
            result = processed_dataset.all
            route.features.inject(result){|res, f| f.process_output(processed_dataset, res, params)}
        end
        
        def post
            data = params[route.name.singularize]
            data and data.kind_of?(Hash) or raise(ArgumentError, "Can't create resource from #{data.inspect}")
            to_set = data.symbolize_keys.merge(@additional_params)
            ensure_associations(to_set)

            response.status = 201
            model.create(to_set).tap{|o|
                response.headers['location'] = "#{route.url_for(o, @base)}.json"
            }
        end

        include HTTPMethodResponder

        private

        def ensure_associations(data)
            data.select{|key, _| model.associations.include?(key)}.each do |key, values|
                values.kind_of?(Hash) or raise(ArgumentError, "Can't create associated object from #{values.inspect}")
                values = values.symbolize_keys
                association = model.association_reflection(key) or
                    raise(RuntimeError, "Association not found: #{model}/#{key}")
                    
                associated_model = association[:class] || association[:cache][:class]
                associated_object = if values.keys.include?(associated_model.primary_key)
                    k = values[associated_model.primary_key]
                    associated_model[k] or raise(RuntimeError, "Can't find associated object #{key} by primary key #{k.inspect}")
                else
                    associated_model.find_or_create(values)
                end
                data[key] = associated_object
            end
        end
    end
end
