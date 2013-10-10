$LOAD_PATH.unshift File.expand_path('../../test', __FILE__)
require 'test_helper'

class RedisKeyMapperTest < MiniTest::Unit::TestCase
  def test_output_of_gemd_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.gemd_set_for(Movie, 1), 'recommendable:users:1:gemd_movies'
  end

  def test_output_of_disgemd_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.disgemd_set_for(Movie, 1), 'recommendable:users:1:disgemd_movies'
  end

  def test_output_of_hidden_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.hidden_set_for(Movie, 1), 'recommendable:users:1:hidden_movies'
  end

  def test_output_of_bookmarked_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.bookmarked_set_for(Movie, 1), 'recommendable:users:1:bookmarked_movies'
  end

  def test_output_of_recommended_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.recommended_set_for(Movie, 1), 'recommendable:users:1:recommended_movies'
  end

  def test_output_of_similarity_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.similarity_set_for(1), 'recommendable:users:1:similarities'
  end

  def test_output_of_gemd_by_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.gemd_by_set_for(Movie, 1), 'recommendable:movies:1:gemd_by'
  end

  def test_output_of_disgemd_by_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.disgemd_by_set_for(Movie, 1), 'recommendable:movies:1:disgemd_by'
  end

  def test_output_of_score_set_for
    assert_equal Recommendable::Helpers::RedisKeyMapper.score_set_for(Movie), 'recommendable:movies:scores'
  end
end
