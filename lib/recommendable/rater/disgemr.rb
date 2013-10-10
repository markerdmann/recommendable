module Recommendable
  module Rater
    module Disgemr
      # Disgem an object. This will remove the item from a user's set of gems
      # or hidden items
      #
      # @param [Object] obj the object to be disgemd
      # @return true if object was disgemd successfully
      # @raise [ArgumentError] if the passed object was not declared ratable
      def disgem(obj)
        raise(ArgumentError, 'Object has not been declared ratable.') unless obj.respond_to?(:recommendable?) && obj.recommendable?
        return if disgems?(obj)

        run_hook(:before_disgem, obj)
        Recommendable.redis.sadd(Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(obj.class, id), obj.id)
        Recommendable.redis.sadd(Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(obj.class, obj.id), id)
        run_hook(:after_disgem, obj)

        true
      end

      # Check whether the user has disgemd an object.
      #
      # @param [Object] obj the object in question
      # @return true if the user has disgemd obj, false if not
      def disgems?(obj)
        Recommendable.redis.sismember(Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(obj.class, id), obj.id)
      end

      # Undisgem an object. This removes the object from a user's set of disgems.
      #
      # @param [Object] obj the object to be undisgemd
      # @return true if the object was disgemd successfully, nil if the object wasn't already disgemd
      def undisgem(obj)
        return unless disgems?(obj)

        run_hook(:before_undisgem, obj)
        Recommendable.redis.srem(Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(obj.class, id), obj.id)
        Recommendable.redis.srem(Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(obj.class, obj.id), id)
        run_hook(:after_undisgem, obj)

        true
      end

      # Retrieve an array of objects the user has disgemd
      #
      # @return [Array] an array of records
      def disgems
        Recommendable.config.ratable_classes.map { |klass| disgemd_for(klass) }.flatten
      end

      # Retrieve an array of objects both this user and another user have disgemd
      #
      # @return [Array] an array of records
      def disgems_in_common_with(user)
        Recommendable.config.ratable_classes.map { |klass| disgemd_in_common_with(klass, user) }.flatten
      end

      # Get the number of items the user has disgemd
      #
      # @return [Fixnum] the number of disgemd items
      def disgems_count
        Recommendable.config.ratable_classes.inject(0) do |sum, klass|
          sum + disgemd_count_for(klass)
        end
      end

      private

      # Fetch IDs for objects belonging to a passed class that the user has disgemd
      #
      # @param [String, Symbol, Class] the class for which you want IDs
      # @return [Array] an array of IDs
      # @private
      def disgemd_ids_for(klass)
        ids = Recommendable.redis.smembers(Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, id))
        ids.map!(&:to_i) if [:active_record, :data_mapper, :sequel].include?(Recommendable.config.orm)
        ids
      end

      # Fetch records belonging to a passed class that the user has disgemd
      #
      # @param [String, Symbol, Class] the class for which you want disgemd records
      # @return [Array] an array of disgemd records
      # @private
      def disgemd_for(klass)
        Recommendable.query(klass, disgemd_ids_for(klass))
      end

      # Get the number of items belonging to a passed class that the user has disgemd
      #
      # @param [String, Symbol, Class] the class for which you want a count of disgems
      # @return [Fixnum] the number of disgems
      # @private
      def disgemd_count_for(klass)
        Recommendable.redis.scard(Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, id))
      end

      # Get a list of records that both this user and a passed user have disgemd
      #
      # @param [User] the other user
      # @param [String, Symbol, Class] the class of common disgemd items
      # @return [Array] an array of records both users have disgemd
      # @private
      def disgemd_in_common_with(klass, user)
        Recommendable.query(klass, disgemd_ids_in_common_with(klass, user))
      end

      # Get a list of IDs for records that both this user and a passed user have
      # disgemd
      #
      # @param [User, Fixnum] the other user (or its ID)
      # @param [String, Symbol, Class] the class of common disgemd items
      # @return [Array] an array of IDs for records that both users have disgemd
      # @private
      def disgemd_ids_in_common_with(klass, user_id)
        user_id = user_id.id if user_id.is_a?(Recommendable.config.user_class)
        Recommendable.redis.sinter(Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, id), Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, user_id))
      end
    end
  end
end
