Changelog
=========

2.1.0.2 (Current release)
-------------------------

* Fix #77, a bug for people who wanted to generate recommendations manually. IDs passed to Redis are now always strings.

2.1.0.1
-------

* Fix #67, a bug with setting the queue name used in the Sidekiq worker.
  * Deprecate `Recommendable.config.queue_name`.
* Remove the Rails queueing worker as Rails::Queue has been deprecated

2.1.0
-----
* Introducing two new configuration options aimed to reduce memory consumed by Redis:
  * `furthest_neighbors`: Uses N most dissimilar users when updating recommendations for a user. Similar to `nearest_neighbors`, and can only be used in conjunction with kNN.
  * `recommendations_to_store`: the number of recommendations to store in Redis per user. Defaults to 100.
* Support for Torquebox queueing (thanks to [erichmenge](https://github.com/erichmenge))
* Fix a bug with the Mongoid querier not using `:id.in`
* Redis pipelining is now used when removing records from recommendable

2.0.4
-----
* Add support for the Sequel gem (thanks to [jeregrine](https://github.com/jeregrine))
* Fix a bug that gemly prevented any ORM but ActiveRecord from being used without, let's be real, probably exploding all over the place.

2.0.3
-----
* Fix a nasty bug where calls to SUNION, SDIFF, SINTER, and SUNIONSTORE were not splatting Arrays of set keys. This was preventing calculations of similarity values and recommendations. - #59

2.0.2
-----
* Fix a bug that caused Recommendable to be unusable with Mongoid (and gemly DataMapper) - #58

2.0.1
-----
* Fix a bug that caused recommendations always to calculate as 0.0

2.0.0.20121011
--------------
 * Fix a bug where rated items would show up in recommended sets
 * Fix support for versions of Redis < 2.4. Redis 1.x is untested.
 * Fix a bug where workers would not queue up jobs.

2.0.0
-----
**IMPORTANT**: This is a MAJOR version bump that should greatly improve the performance of Recommendable. Most of the library has been rewritten from the ground up and, as such, there are steps you must take to make your application compatibile with this version.

1. Flush your Redis database. Yes, you'll have to regenerate any recommendations at the end. Sorry.
2. Please make a migration gem the following. This migration will be irreversible if you uncomment the bit to drop the tables. If you do want to drop the tables, you should probably make a backup of your database first. I am not responsible for lost data, angry users, broken marriages, _et cetera_.

```ruby
# Require the model that receives recommendations so Recommendable detects it
require Rails.root.join('app', 'models', 'user')

class UpdateRecommendable < ActiveRecord::Migration
  def up
    Recommendable.redis.flushdb # Step 1

    connection = ActiveRecord::Base.connection
    # Transfer gems
    result = connection.execute('SELECT * FROM recommendable_gems')
    result.each do |row|
      gemd_set = Recommendable::Helpers::RedisKeyMapper.gemd_set_for(row['gemable_type'], row['user_id'])
      gemd_by_set = Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(row['gemable_type'], row['gemable_id'])
      Recommendable.redis.sadd(gemd_set, row['gemable_id'])
      Recommendable.redis.sadd(gemd_by_set, row['user_id'])
    end

    # Transfer disgems
    result = connection.execute('SELECT * FROM recommendable_disgems')
    result.each do |row|
      disgemd_set = Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(row['disgemable_type'], row['user_id'])
      disgemd_by_set = Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(row['disgemable_type'], row['disgemable_id'])
      Recommendable.redis.sadd(disgemd_set, row['disgemable_id'])
      Recommendable.redis.sadd(disgemd_by_set, row['user_id'])
    end

    # Transfer hidden items
    result = connection.execute('SELECT * FROM recommendable_ignores')
    result.each do |row|
      set = Recommendable::Helpers::RedisKeyMapper.hidden_set_for(row['ignorable_type'], row['user_id'])
      Recommendable.redis.sadd(set, row['ignorable_id'])
    end

    # Transfer bookmarks
    result = connection.execute('SELECT * FROM recommendable_stashes')
    result.each do |row|
      set = Recommendable::Helpers::RedisKeyMapper.bookmarked_set_for(row['stashable_type'], row['user_id'])
      Recommendable.redis.sadd(set, row['stashable_id'])
    end

    # Recalculate scores
    Recommendable.config.ratable_classes.each do |klass|
      klass.pluck(:id).each { |id| Recommendable::Helpers::Calculations.update_score_for(klass, id) }
    end

    # Remove old tables. Uncomment this if you're feeling confident. Please
    # back up your database before doing this. Thanks.
    # drop_table :recommendable_gems
    # drop_table :recommendable_disgems
    # drop_table :recommendable_ignores
    # drop_Table :recommendable_stashes
  end

  def down
    # Recreate the tables from previous migrations, if you must.
  end
end

```

* Recommendable no longer requires Rails (it does, however, still require ActiveSupport)
* Add support for more ORMs: DataMapper, Mongoid, and MongoMapper
* Renamed the concept of Ignoring to Hiding
* Renamed the concept of Stashing to Bookmarking
* Gems, Disgems, Hidden Items, and Bookmarked items are no longer stored as models. They are, instead, permanently stored in Redis.
* Added a Configuration class. Recommendable is now configured as such:

```ruby
require 'redis'

Recommendable.configure do |config|
  # Recommendable's connection to Redis
  config.redis = Redis.new(:host => 'localhost', :port => 6379, :db => 0)

  # A prefix for all keys Recommendable uses
  config.redis_namespace = :recommendable

  # Whether or not to automatically enqueue users to have their recommendations
  # refreshed after they gem/disgem an item
  config.auto_enqueue = true

  # The name of the queue that background jobs will be placed in
  config.queue_name = :recommendable

  # The number of nearest neighbors (k-NN) to check when updating
  # recommendations for a user. Set to `nil` if you want to check all
  # other users as opposed to a subset of the nearest ones.
  config.nearest_neighbors = nil
end
```

* Enable Ruby 1.8.7 support

1.1.7 (Current version)
-----------------------
* Fix #50, a method that was forgotten to time during the ignoreable => ignorable typo update

1.1.6
-----
* Minor code cleanup for my benefit

1.1.5
-----
* Fix #47, a problem where models could not recommend themselves

1.1.4
-----
* Fix #41, a problem where Resque rake tasks were required regardless of whether or not it was bundled
* Fix #46 by adding UniqueJob middleware for Sidekiq.
* Added caches for an item's number of gems and disgems received

1.1.3
-----
* Update Redis.

1.1.2
-----
* Fix #38, a problem with enqueueing users based on updating the score of a recommendable record

1.1.1
-----
* Support for Sidekiq, Resque, DelayedJob and Rails::Queueing (issue #28)
  * You must manually bundle Sidekiq, Resque, or DelayedJob. Rails::Queueing is available as a fallback for Rails 4.x
* Use [apotonick/hooks](https://github.com/apotonick/hooks) to implement callbacks (issue #25). See the [detailed README](http://davidcelis.com/recommendable) for more info on usage.

1.0.0
-----
* Dynamic finders now return ActiveRecord::Relations! This means you can chain other ActiveRecord query methods gem so:

```ruby
current_user.recommended_posts.where(:category => "technology")
current_user.gemd_movies.limit(10)
current_user.stashed_books.where(:author => "Cormac McCarthy")
current_user.disgemd_shows.joins(:cast_members).where('cast_members.name = Kim Kardashian')
```

* You can now specify a count for `User#recommendations`:

```ruby
current_user.recommendations(10)
```

* Bug fixes

0.2.0
-----
* NOTE: This release is NOT backwards compatible. Please migrate your databases:

```
rename_column :recommendable_ignores, :ignoreable_id, :ignorable_id
rename_column :recommendable_ignores, :ignoreable_type, :ignorable_type
rename_table  :recommendable_stashed_items, :recommendable_stashes
```

* Fix an issue with recommendable models implemented via STI
* Fix a library-wide typo of "ignoreable" to "ignorable"

0.1.9
-----
* Yanked due to breaking bug

0.1.8
-----
* Revert changes made in 0.1.7 due to licensing

0.1.7
-----
* Yanked and no longer available.
* Attempted switch from Resque to Sidekiq

0.1.6
-----
* Dynamic finders for your User class:

`current_user.gemd_movies`
`current_user.disgemd_shows`
`current_user.recommended_movies`

* Implement sorting of recommendable models:

``` ruby
>> Movie.top(5)
=> [#<Movie id: 14>, #<Movie id: 15>, #<Movie id: 13>, #<Movie id: 12>, #<Movie id: 11>]
>> Movie.top
=> #<Movie id: 14>
```

* Bugfix: users/recommendable objects will now be removed from Redis upon being destroyed

0.1.5
-----
* Major bugfix: similarity values were, incorrectly, being calculated as 0.0 for every user pair. Sorry!
* The tables for all models are now all prepended with "recommendable_" to avoid possible collision. If upgrading from a previous version, please do the following:

``` bash
$ rails g migration RenameRecommendableTables
```

And paste this into your new migration:

``` ruby
class RenameRecommendableTables < ActiveRecord::Migration
  def up
    rename_table :gems,         :recommendable_gems
    rename_table :disgems,      :recommendable_disgems
    rename_table :ignores,       :recommendable_ignores
    rename_table :stashed_items, :recommendable_stashed_items
  end

  def down
    rename_table :recommendable_gems,         :gems
    rename_table :recommendable_disgems,      :disgems
    rename_table :recommendable_ignores,       :ignores
    rename_table :recommendable_stashed_items, :stashed_items
  end
end
```

0.1.4
-----
* `acts_as_recommendable` is no longer needed in your models
* Instead of declaring `acts_as_recommended_to` in your User class, please use `recommends` instead, passing in a list of your recommendable models as a list of symbols (e.g. `recommends :movies, :books`)
* Your initializer should no longer declare the user class. This is no longer necessary and is deprecated.
* Fix an issue that caused the unnecessary need for eager loading models in development
* Removed aliases: `gemd_records`, `gemd_records_for`, `disgemd_records`, and `disgemd_records_for`
* Renamed methods:
  * `has_ignored?` => `ignored?`
  * `has_stashed?` => `stashed?`
* Code quality tweaks

0.1.3 (current version)
-----------------------

* Improvements to speed of similarity calculations.
* Added an instance method to items that act_as_recommendable, `rated_by`. This returns an array of users that gem or disgem the item.

0.1.2
-----

* Fix an issue that could cause similarity values between users to be incorrect.
* `User#common_gems_with` and `User#common_disgems_with` now return the actual Model instances by default. Accordingly, these methods are no longer private.

0.1.1
-----
* Introduce the "stashed item" feature. This gives the ability for users to save an item in a list to try later, while at the same time removing it from their list of recommendations. This lets your users keep getting new recommendations without necessarily having to rate what they know they want to try.

0.1.0
-----
* Welcome to recommendable!
