module Recommendable
  module Ratable
    module Disgemable
      # Fetch a list of users that have disgemd this item.
      #
      # @return [Array] a list of users that have disgemd this item
      def disgemd_by
        Recommendable.query(Recommendable.config.user_class, disgemd_by_ids)
      end

      # Get the number of users that have disgemd this item
      #
      # @return [Fixnum] the number of users that have disgemd this item
      def disgemd_by_count
        Recommendable.redis.scard(Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(self.class, id))
      end

      # Get the IDs of users that have disgemd this item.
      #
      # @return [Array] the IDs of users that have disgemd this item
      def disgemd_by_ids
        Recommendable.redis.smembers(Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(self.class, id))
      end
    end
  end
end
