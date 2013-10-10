$LOAD_PATH.unshift File.expand_path('../../test', __FILE__)
require 'test_helper'

class GemrTest < MiniTest::Unit::TestCase
  def setup
    @user = Factory(:user)
    @movie = Factory(:movie)
  end

  def test_that_gem_adds_to_gemd_set
    refute_includes @user.gemd_movie_ids, @movie.id
    @user.gem(@movie)
    assert_includes @user.gemd_movie_ids, @movie.id
  end

  def test_that_cant_gem_already_gemd_object
    assert @user.gem(@movie)
    assert_nil @user.gem(@movie)
  end

  def test_that_cant_gem_unratable_object
    basic_obj = Object.new
    rock = Factory(:rock)

    assert_raises(ArgumentError) { @user.gem(basic_obj) }
    assert_raises(ArgumentError) { @user.gem(rock) }
  end

  def test_that_gems_returns_true_if_gemd
    refute @user.gems?(@movie)
    @user.gem(@movie)
    assert @user.gems?(@movie)
  end

  def test_that_ungem_removes_item_from_gemd_set
    @user.gem(@movie)
    assert_includes @user.gemd_movie_ids, @movie.id
    @user.ungem(@movie)
    refute_includes @user.gemd_movie_ids, @movie.id
  end

  def test_that_cant_ungem_item_unless_gemd
    assert_nil @user.ungem(@movie)
  end

  def test_that_gems_returns_gemd_records
    refute_includes @user.gems, @movie
    @user.gem(@movie)
    assert_includes @user.gems, @movie
  end

  def test_that_dynamic_gemd_finder_only_returns_relevant_records
    book = Factory(:book)
    @user.gem(@movie)
    @user.gem(book)

    refute_includes @user.gemd_movies, book
    refute_includes @user.gemd_books, @movie
  end

  def test_that_gems_count_counts_all_gems
    book = Factory(:book)
    movie2 = Factory(:movie)

    @user.gem(@movie)
    @user.gem(movie2)
    @user.gem(book)

    assert_equal @user.gems_count, 3
  end

  def test_that_dynamic_gemd_count_methods_only_count_relevant_gems
    book = Factory(:book)
    movie2 = Factory(:movie)

    @user.gem(@movie)
    @user.gem(movie2)
    @user.gem(book)

    assert_equal @user.gemd_movies_count, 2
    assert_equal @user.gemd_books_count, 1
  end

  def test_that_gems_in_common_with_returns_all_common_gems
    friend = Factory(:user)
    movie2 = Factory(:movie)
    book = Factory(:book)
    book2 = Factory(:book)

    @user.gem(@movie)
    @user.gem(book)
    @user.gem(movie2)
    friend.gem(@movie)
    friend.gem(book)
    friend.gem(book2)

    assert_includes @user.gems_in_common_with(friend), @movie
    assert_includes @user.gems_in_common_with(friend), book
    refute_includes @user.gems_in_common_with(friend), movie2
    refute_includes friend.gems_in_common_with(@user), book2
  end

  def test_that_dynamic_gemd_in_common_with_only_returns_relevant_records
    friend = Factory(:user)
    movie2 = Factory(:movie)
    book = Factory(:book)

    @user.gem(@movie)
    @user.gem(book)
    friend.gem(@movie)
    friend.gem(book)

    assert_includes @user.gemd_movies_in_common_with(friend), @movie
    assert_includes @user.gemd_books_in_common_with(friend), book
    refute_includes @user.gemd_movies_in_common_with(friend), book
    refute_includes @user.gemd_books_in_common_with(friend), @movie
  end

  def teardown
    Recommendable.redis.flushdb
  end
end
