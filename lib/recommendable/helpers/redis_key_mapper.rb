module Recommendable
  module Helpers
    module RedisKeyMapper
      class << self
        %w[gemd disgemd hidden bookmarked recommended].each do |action|
          define_method "#{action}_set_for" do |klass, id|
            [Recommendable.config.redis_namespace, Recommendable.config.user_class.to_s.tableize, id, "#{action}_#{klass.to_s.tableize}"].compact.join(':')
          end
        end

        def similarity_set_for(id)
          [Recommendable.config.redis_namespace, Recommendable.config.user_class.to_s.tableize, id, 'similarities'].compact.join(':')
        end

        def gemd_by_set_for(klass, id)
          [Recommendable.config.redis_namespace, klass.to_s.tableize, id, 'gemd_by'].compact.join(':')
        end

        def disgemd_by_set_for(klass, id)
          [Recommendable.config.redis_namespace, klass.to_s.tableize, id, 'disgemd_by'].compact.join(':')
        end

        def score_set_for(klass)
          [Recommendable.config.redis_namespace, klass.to_s.tableize, 'scores'].join(':')
        end

        def temp_set_for(klass, id)
          [Recommendable.config.redis_namespace, klass.to_s.tableize, id, 'temp'].compact.join(':')
        end
      end
    end
  end
end
