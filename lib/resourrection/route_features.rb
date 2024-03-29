module Resourrection
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
            dataset.limit(pagesize, (page-1)*pagesize)
        end

        #def process_output(dataset, output, params)
            #page, pagesize = process_params(params)
            ##total = (dataset.unlimited.count / pagesize.to_f).ceil

            #{
                #'content' => output,
                #'pager' => {
                    #'page' => page,
                    #'next' => page+1
                    ##'next' => (page >= total ? nil : page+1),
                    ##'total' => total
                #}
            #}
        #end

        def process_params(params)
            page = params[@page_param_name] || 1
            pagesize = params[@pagesize_param_name] || @default or
                raise(ArgumentError, "No pagesize param provided")

            [page.to_i, pagesize.to_i]
        end
    end

    class Ordered < RouteFeature
        def initialize(order_param_name, options = {})
            @order_param_name = order_param_name
            @orders = options.delete(:orders) or raise(ArgumentError, "ordered feature requires :orders param")
            @default = options.delete(:default)
            @descending = options.delete(:descending)
        end
        
        def process_dataset(dataset, params)
            order_sym = process_params(params)
            dataset.order(order_sym)
        end

        def process_params(params)
            order = params[@order_param_name] || @default
            order_direction, order_name = order.scan(/^(\+|-|)(.+)$/).flatten
            sym = @orders[order_name] or
                raise(ArgumentError, "Unsupported order: #{order_name.inspect}")

            if @descending
                order_direction == '-' ? sym.asc : sym.desc
            else
                order_direction == '-' ? sym.desc : sym.asc
            end
        end
    end

    class Filtered < RouteFeature
        def initialize(filter_param_name, options = {}, &block)
            @filter_param_name = filter_param_name
            @filters = {}
            instance_eval &block
        end

        def process_dataset(dataset, params)
            filters = params[@filter_param_name] || []
            filters.inject(dataset){|ds, (name, val)|
                filter = @filters[name] or raise(ArgumentError, "Unknown filter #{name.inspect}")
                filter.apply(ds, val)
            }
        end

        private

        def on(name, type=:string, &processor)
            @filters[name] = Filter.new(name, type, processor)
        end

        class Filter
            def initialize(name, type, processor)
                @name, @type, @processor = name, type, processor
            end

            def apply(dataset, value)
                value = parse(value.to_s)
                @processor.call(dataset, value)
            end

            def parse(value)
                case @type
                when :string
                    value
                when :array
                    value.split(/\s*,\s*/)
                when :like
                    "%#{value}%"
                when :numeric
                    value.to_i
                when :numeric_array
                    value.split(/\s*,\s*/).map(&:to_i)
                when :boolean
                    case value
                    when 'true'
                        true
                    when 'false'
                        false
                    else
                        raise ArgumentError, "Unparseable value #{value.inspect} for filter #{@name}"
                    end
                when :time
                    Time.parse(value)
                else
                    raise ArgumentError, "Can't parse filter #{@name} typed #{@type.inspect}"
                end
            end
        end
    end

    class Adjusted < RouteFeature
        def initialize(&block)
            @adjuster = block
        end

        def process_dataset(dataset, *)
            @adjuster.call(dataset)
        end
    end
end
