$LOAD_PATH.unshift File.expand_path('../../test', __FILE__)
require 'test_helper'

class GemableTest < MiniTest::Unit::TestCase
  def setup
    @user = Factory(:user)
    @friend = Factory(:user)
    @movie = Factory(:movie)
  end

  def test_gemd_by_returns_relevant_users
    assert_empty @movie.gemd_by
    @user.gem(@movie)
    assert_includes @movie.gemd_by, @user
    refute_includes @movie.gemd_by, @friend
    @friend.gem(@movie)
    assert_includes @movie.gemd_by, @friend
  end

  def test_gemd_by_count_returns_an_accurate_count
    assert_empty @movie.gemd_by
    @user.gem(@movie)
    assert_equal @movie.gemd_by_count, 1
    @friend.gem(@movie)
    assert_equal @movie.gemd_by_count, 2
  end

  def teardown
    Recommendable.redis.flushdb
  end
end
