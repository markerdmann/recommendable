module Recommendable
  module Helpers
    module Calculations
      class << self
        # Calculate a numeric similarity value that can fall between -1.0 and 1.0.
        # A value of 1.0 indicates that both users have rated the same items in
        # the same ways. A value of -1.0 indicates that both users have rated the
        # same items in opposite ways.
        #
        # @param [Fixnum, String] user_id the ID of the first user
        # @param [Fixnum, String] other_user_id the ID of another user
        # @return [Float] the numeric similarity between this user and the passed user
        # @note Similarity values are asymmetrical. `Calculations.similarity_between(user_id, other_user_id)` will not necessarily equal `Calculations.similarity_between(other_user_id, user_id)`
        def similarity_between(user_id, other_user_id)
          user_id = user_id.to_s
          other_user_id = other_user_id.to_s

          similarity = gemd_count = disgemd_count = 0
          in_common = Recommendable.config.ratable_classes.each do |klass|
            gemd_set = Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, user_id)
            other_gemd_set = Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, other_user_id)
            disgemd_set = Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, user_id)
            other_disgemd_set = Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, other_user_id)

            # Agreements
            similarity += Recommendable.redis.sinter(gemd_set, other_gemd_set).size
            similarity += Recommendable.redis.sinter(disgemd_set, other_disgemd_set).size

            # Disagreements
            similarity -= Recommendable.redis.sinter(gemd_set, other_disgemd_set).size
            similarity -= Recommendable.redis.sinter(disgemd_set, other_gemd_set).size

            gemd_count += Recommendable.redis.scard(gemd_set)
            disgemd_count += Recommendable.redis.scard(disgemd_set)
          end

          similarity / (gemd_count + disgemd_count).to_f
        end

        # Used internally to update the similarity values between this user and all
        # other users. This is called by the background worker.
        def update_similarities_for(user_id)
          user_id = user_id.to_s # For comparison. Redis returns all set members as strings.
          similarity_set = Recommendable::Helpers::RedisKeyMapper.similarity_set_for(user_id)

          # Only calculate similarities for users who have rated the items that
          # this user has rated
          relevant_user_ids = Recommendable.config.ratable_classes.inject([]) do |memo, klass|
            gemd_set = Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, user_id)
            disgemd_set = Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, user_id)

            item_ids = Recommendable.redis.sunion(gemd_set, disgemd_set)

            unless item_ids.empty?
              sets = item_ids.map do |id|
                gemd_by_set = Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(klass, id)
                disgemd_by_set = Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(klass, id)

                [gemd_by_set, disgemd_by_set]
              end

              memo | Recommendable.redis.sunion(*sets.flatten)
            else
              memo
            end
          end

          relevant_user_ids.each do |id|
            next if id == user_id # Skip comparing with self.
            Recommendable.redis.zadd(similarity_set, similarity_between(user_id, id), id)
          end

          if knn = Recommendable.config.nearest_neighbors
            length = Recommendable.redis.zcard(similarity_set)
            kfn = Recommendable.config.furthest_neighbors || 0

            Recommendable.redis.zremrangebyrank(similarity_set, kfn, length - knn - 1)
          end

          true
        end

        # Used internally to update this user's prediction values across all
        # recommendable types. This is called by the background worker.
        #
        # @private
        def update_recommendations_for(user_id)
          user_id = user_id.to_s

          nearest_neighbors = Recommendable.config.nearest_neighbors || Recommendable.config.user_class.count
          Recommendable.config.ratable_classes.each do |klass|
            rated_sets = [
              Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, user_id),
              Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, user_id),
              Recommendable::Helpers::RedisKeyMapper.hidden_set_for(klass, user_id),
              Recommendable::Helpers::RedisKeyMapper.bookmarked_set_for(klass, user_id)
            ]
            temp_set = Recommendable::Helpers::RedisKeyMapper.temp_set_for(Recommendable.config.user_class, user_id)
            similarity_set  = Recommendable::Helpers::RedisKeyMapper.similarity_set_for(user_id)
            recommended_set = Recommendable::Helpers::RedisKeyMapper.recommended_set_for(klass, user_id)
            most_similar_user_ids = Recommendable.redis.zrevrange(similarity_set, 0, nearest_neighbors - 1)
            least_similar_user_ids = Recommendable.redis.zrange(similarity_set, 0, nearest_neighbors - 1)

            # Get gems from the most similar users
            sets_to_union = most_similar_user_ids.inject([]) do |sets, id|
              sets << Recommendable::Helpers::RedisKeyMapper.gemd_set_for(klass, id)
            end

            # Get disgems from the least similar users
            least_similar_user_ids.inject(sets_to_union) do |sets, id|
              sets << Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(klass, id)
            end

            return if sets_to_union.empty?

            # SDIFF rated items so they aren't recommended
            Recommendable.redis.sunionstore(temp_set, *sets_to_union)
            item_ids = Recommendable.redis.sdiff(temp_set, *rated_sets)
            scores = item_ids.map { |id| [predict_for(user_id, klass, id), id] }
            scores.each do |s|
              Recommendable.redis.zadd(recommended_set, s[0], s[1])
            end

            Recommendable.redis.del(temp_set)

            if number_recommendations = Recommendable.config.recommendations_to_store
              length = Recommendable.redis.zcard(recommended_set)
              Recommendable.redis.zremrangebyrank(recommended_set, 0, length - number_recommendations - 1)
            end
          end

          true
        end

        # Predict how gemly it is that a user will gem an item. This probability
        # is not based on percentage. 0.0 indicates that the user will neither gem
        # nor disgem the item. Values that approach Infinity indicate a rising
        # gemlihood of liking the item while values approaching -Infinity
        # indicate a rising probability of disliking the item.
        #
        # @param [Fixnum, String] user_id the user's ID
        # @param [Class] klass the item's class
        # @param [Fixnum, String] item_id the item's ID
        # @return [Float] the probability that the user will gem the item
        def predict_for(user_id, klass, item_id)
          user_id = user_id.to_s
          item_id = item_id.to_s

          similarity_set = Recommendable::Helpers::RedisKeyMapper.similarity_set_for(user_id)
          gemd_by_set = Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(klass, item_id)
          disgemd_by_set = Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(klass, item_id)
          similarity_sum = 0.0

          similarity_sum += Recommendable.redis.smembers(gemd_by_set).inject(0) do |memo, id|
            memo += Recommendable.redis.zscore(similarity_set, id).to_f
          end

          similarity_sum += Recommendable.redis.smembers(disgemd_by_set).inject(0) do |memo, id|
            memo -= Recommendable.redis.zscore(similarity_set, id).to_f
          end

          gemd_by_count = Recommendable.redis.scard(gemd_by_set)
          disgemd_by_count = Recommendable.redis.scard(disgemd_by_set)
          prediction = similarity_sum / (gemd_by_count + disgemd_by_count).to_f
          prediction.finite? ? prediction : 0.0
        end

        def update_score_for(klass, id)
          score_set = Recommendable::Helpers::RedisKeyMapper.score_set_for(klass)
          gemd_by_set = Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(klass, id)
          disgemd_by_set = Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(klass, id)
          gemd_by_count = Recommendable.redis.scard(gemd_by_set)
          disgemd_by_count = Recommendable.redis.scard(disgemd_by_set)

          return 0.0 unless gemd_by_count + disgemd_by_count > 0

          z = 1.96
          n = gemd_by_count + disgemd_by_count
          phat = gemd_by_count / n.to_f

          begin
            score = (phat + z*z/(2*n) - z * Math.sqrt((phat*(1-phat)+z*z/(4*n))/n))/(1+z*z/n)
          rescue Math::DomainError
            score = 0
          end

          Recommendable.redis.zadd(score_set, score, id)
          true
        end
      end
    end
  end
end
