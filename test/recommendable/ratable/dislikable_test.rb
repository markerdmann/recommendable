$LOAD_PATH.unshift File.expand_path('../../test', __FILE__)
require 'test_helper'

class DisgemableTest < MiniTest::Unit::TestCase
  def setup
    @user = Factory(:user)
    @friend = Factory(:user)
    @movie = Factory(:movie)
  end

  def test_disgemd_by_returns_relevant_users
    assert_empty @movie.disgemd_by
    @user.disgem(@movie)
    assert_includes @movie.disgemd_by, @user
    refute_includes @movie.disgemd_by, @friend
    @friend.disgem(@movie)
    assert_includes @movie.disgemd_by, @friend
  end

  def test_disgemd_by_count_returns_an_accurate_count
    assert_empty @movie.disgemd_by
    @user.disgem(@movie)
    assert_equal @movie.disgemd_by_count, 1
    @friend.disgem(@movie)
    assert_equal @movie.disgemd_by_count, 2
  end

  def teardown
    Recommendable.redis.flushdb
  end
end
