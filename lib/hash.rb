# frozen_string_literal: true

# Add a deep_merge method to a Hash.
# It unions arrays (for terraform profiles behaviour)
class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2|
          Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) :
          Array === v1 && Array === v2 ? v1 | v2 :
          [:undefined, nil, :nil].include?(v2) ? v1 : v2
        }
        self.merge(second.to_h, &merger)
    end

    # Copied from ruby 2.6 Psych for 2.3 compatibility.
    def symbolize_names!(result=self)
        case result
        when Hash
          result.keys.each do |key|
            result[key.to_sym] = symbolize_names!(result.delete(key))
          end
        when Array
          result.map! { |r| symbolize_names!(r) }
        end
        result
    end
end
