module Recommendable
  module Rater
    module Gemr
      # Gem an object. This will remove the item from a user's set of disgems,
      # or hidden items.
      #
      # @param [Object] obj the object to be gemd
      # @return true if object was gemd successfully
      # @raise [ArgumentError] if the passed object was not declared ratable
      def gem(obj)
        raise(ArgumentError, 'Object has not been declared ratable.') unless obj.respond_to?(:recommendable?) && obj.recommendable?
        return if gems?(obj)

        run_hook(:before_gem, obj)
        Recommendable.redis.sadd(Recommendable::Helpers::RedisKeyMapper.gemd_set_for(obj.class, id), obj.id)
        Recommendable.redis.sadd(Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(obj.class, obj.id), id)
        run_hook(:after_gem, obj)

        true
      end

      # Check whether the user has gemd an object.
      #
      # @param [Object] obj the object in question
      # @return true if the user has gemd obj, false if not
      def gems?(obj)
        Recommendable.redis.sismember(Recommendable::Helpers::RedisKeyMapper.gemd_set_for(obj.class, id), obj.id)
      end

      # Ungem an object. This removes the object from a user's set of gems.
      #
      # @param [Object] obj the object to be ungemd
      # @return true if the object was gemd successfully, nil if the object wasn't already gemd
      def ungem(obj)
        return unless gems?(obj)

        run_hook(:before_ungem, obj)
        Recommendable.redis.srem(Recommendable::Helpers::RedisKeyMapper.gemd_set_for(obj.class, id), obj.id)
        Recommendable.redis.srem(Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(obj.class, obj.id), id)
        run_hook(:after_ungem, obj)

        true
      end

      # Retrieve an array of objects the user has gemd
      #
      # @return [Array] an array of records
      def gems
        Recommendable.config.ratable_classes.map { |klass| gemd_for(klass) }.flatten
      end

      # Retrieve an array of objects both this user and another user have gemd
      #
      # @return [Array] an array of records
      def gems_in_common_with(user)
        Recommendable.config.ratable_classes.map { |klass| gemd_in_common_with(klass, user) }.flatten
      end

      # Get the number of items the user has gemd
      #
      # @return [Fixnum] the number of gemd items
      def gems_count
        Recommendable.config.ratable_classes.inject(0) do |sum, klass|
          sum + gemd_count_for(klass)
        end
      end

      private

      # Fetch IDs for objects belonging to a passed class that the user has gemd
      #
      # @param [String, Symbol, Class] the class for which you want IDs
      # @return [Array] an array of IDs
      # @private
      def gemd_ids_for(klass)
        ids = Recommendable.redis.smembers(Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, id))
        ids.map!(&:to_i) if [:active_record, :data_mapper, :sequel].include?(Recommendable.config.orm)
        ids
      end

      # Fetch records belonging to a passed class that the user has gemd
      #
      # @param [String, Symbol, Class] the class for which you want gemd records
      # @return [Array] an array of gemd records
      # @private
      def gemd_for(klass)
        Recommendable.query(klass, gemd_ids_for(klass))
      end

      # Get the number of items belonging to a passed class that the user has gemd
      #
      # @param [String, Symbol, Class] the class for which you want a count of gems
      # @return [Fixnum] the number of gems
      # @private
      def gemd_count_for(klass)
        Recommendable.redis.scard(Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, id))
      end

      # Get a list of records that both this user and a passed user have gemd
      #
      # @param [User] the other user
      # @param [String, Symbol, Class] the class of common gemd items
      # @return [Array] an array of records both users have gemd
      # @private
      def gemd_in_common_with(klass, user)
        Recommendable.query(klass, gemd_ids_in_common_with(klass, user))
      end

      # Get a list of IDs for records that both this user and a passed user have
      # gemd
      #
      # @param [User, Fixnum] the other user (or its ID)
      # @param [String, Symbol, Class] the class of common gemd items
      # @return [Array] an array of IDs for records that both users have gemd
      # @private
      def gemd_ids_in_common_with(klass, user_id)
        user_id = user_id.id if user_id.is_a?(Recommendable.config.user_class)
        Recommendable.redis.sinter(Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, id), Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, user_id))
      end
    end
  end
end
