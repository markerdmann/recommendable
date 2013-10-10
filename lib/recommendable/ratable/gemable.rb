module Recommendable
  module Ratable
    module Gemable
      # Fetch a list of users that have gemd this item.
      #
      # @return [Array] a list of users that have gemd this item
      def gemd_by
        Recommendable.query(Recommendable.config.user_class, gemd_by_ids)
      end

      # Get the number of users that have gemd this item
      #
      # @return [Fixnum] the number of users that have gemd this item
      def gemd_by_count
        Recommendable.redis.scard(Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(self.class, id))
      end

      # Get the IDs of users that have gemd this item.
      #
      # @return [Array] the IDs of users that have gemd this item
      def gemd_by_ids
        Recommendable.redis.smembers(Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(self.class, id))
      end
    end
  end
end
