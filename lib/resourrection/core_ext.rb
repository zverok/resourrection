class Hash
    # Usage { :a => 1, :b => 2, :c => 3}.except(:a) -> { :b => 2, :c => 3}
    def except(*keys)
        reject{|k, v|
            keys.include? k
        }
    end

    # Usage { :a => 1, :b => 2, :c => 3}.only(:b, :c) -> { :b => 2, :c => 3}
    def only(*keys)
        select{|k, v|
            keys.include? k
        }
    end

    # stolen from ActiveSupport
    def symbolize_keys!
        keys.each do |key|
            self[(key.to_sym rescue key) || key] = delete(key)
        end
        self
    end

    def symbolize_keys
        dup.symbolize_keys!
    end
end
