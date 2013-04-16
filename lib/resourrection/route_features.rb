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

        def process_output(dataset, output, params)
            page, pagesize = process_params(params)
            total = (dataset.unlimited.count / pagesize.to_f).ceil

            {
                'content' => output,
                'pager' => {
                    'page' => page,
                    'next' => (page >= total ? nil : page+1),
                    'total' => total
                }
            }
        end

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

            order_direction == '-' ? sym.desc : sym.asc
        end
    end
end
