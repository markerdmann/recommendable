$LOAD_PATH.unshift File.expand_path('../../test', __FILE__)
require 'test_helper'

class RatableTest < MiniTest::Unit::TestCase
  def setup
    @movie = Factory(:movie)
    @book = Factory(:book)
    @rock = Factory(:rock)
  end

  def test_recommendable_predicate_works
    assert Movie.recommendable?
    assert @movie.recommendable?
    assert Book.recommendable?
    assert @book.recommendable?
    refute Rock.recommendable?
    refute @rock.recommendable?
  end

  def test_rated_predicate_works
    refute @movie.rated?
    user = Factory(:user)
    user.gem(@movie)
    assert @movie.rated?
  end

  def test_top_scope_returns_best_things
    @book2 = Factory(:book)
    @book3 = Factory(:book)
    @user = Factory(:user)
    @friend = Factory(:user)

    @user.gem(@book2)
    @friend.gem(@book2)
    @user.gem(@book3)
    @user.disgem(@book)

    top = Book.top(3)
    assert_equal top[0], @book2
    assert_equal top[1], @book3
    assert_equal top[2], @book
  end

  def test_removed_from_recommendable_upon_destruction
    @user = Factory(:user)
    @friend = Factory(:user)
    @buddy = Factory(:user)
    @user.gem(@movie)
    @friend.disgem(@movie)
    @user.disgem(@book)
    @friend.gem(@book)
    @buddy.hide(@movie)
    @buddy.bookmark(@book)

    gemd_by_sets = [@movie, @book].map { |obj| Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(obj.class, obj.id) }
    disgemd_by_sets = [@movie, @book].map { |obj| Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(obj.class, obj.id) }
    [gemd_by_sets, disgemd_by_sets].flatten.each { |set| assert_equal Recommendable.redis.scard(set), 1 }

    assert @user.gems?(@movie)
    assert @user.disgems?(@book)
    assert @friend.gems?(@book)
    assert @friend.disgems?(@movie)
    assert @buddy.hides?(@movie)
    assert @buddy.bookmarks?(@book)

    @movie.destroy
    @book.destroy

    [gemd_by_sets, disgemd_by_sets].flatten.each { |set| assert_equal Recommendable.redis.scard(set), 0 }

    assert_empty @buddy.hidden_movies
    assert_empty @buddy.bookmarked_books
  end

  def teardown
    Recommendable.redis.flushdb
  end
end
