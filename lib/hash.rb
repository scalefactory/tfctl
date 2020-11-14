# frozen_string_literal: true

# Add a deep_merge method to a Hash.
# It unions arrays (for terraform profiles behaviour)
class Hash
    def deep_merge(second)
        merger = proc { |_key, v1, v2|
            if v1.is_a?(Hash) && v2.is_a?(Hash)
                v1.merge(v2, &merger)
            elsif v1.is_a?(Array) && v2.is_a?(Array)
                v1 | v2
            elsif [:undefined, nil, :nil].include?(v2)
                v1
            else
                v2
            end
        }
        merge(second.to_h, &merger)
    end

    def symbolize_names!(result = self)
        case result
        when Hash
            # rubocop:disable Style/HashEachMethods
            result.keys.each do |key|
                result[key.to_sym] = symbolize_names!(result.delete(key))
            end
            # rubocop:enable Style/HashEachMethods
        when Array
            result.map! { |r| symbolize_names!(r) }
        end
        result
    end
end
