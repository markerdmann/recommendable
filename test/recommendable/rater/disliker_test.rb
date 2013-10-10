$LOAD_PATH.unshift File.expand_path('../../test', __FILE__)
require 'test_helper'

class DisgemrTest < MiniTest::Unit::TestCase
  def setup
    @user = Factory(:user)
    @movie = Factory(:movie)
  end

  def test_that_disgem_adds_to_disgemd_set
    refute_includes @user.disgemd_movie_ids, @movie.id
    @user.disgem(@movie)
    assert_includes @user.disgemd_movie_ids, @movie.id
  end

  def test_that_cant_disgem_already_disgemd_object
    assert @user.disgem(@movie)
    assert_nil @user.disgem(@movie)
  end

  def test_that_cant_disgem_unratable_object
    basic_obj = Object.new
    rock = Factory(:rock)

    assert_raises(ArgumentError) { @user.disgem(basic_obj) }
    assert_raises(ArgumentError) { @user.disgem(rock) }
  end

  def test_that_disgems_returns_true_if_disgemd
    refute @user.disgems?(@movie)
    @user.disgem(@movie)
    assert @user.disgems?(@movie)
  end

  def test_that_undisgem_removes_item_from_disgemd_set
    @user.disgem(@movie)
    assert_includes @user.disgemd_movie_ids, @movie.id
    @user.undisgem(@movie)
    refute_includes @user.disgemd_movie_ids, @movie.id
  end

  def test_that_cant_undisgem_item_unless_disgemd
    assert_nil @user.undisgem(@movie)
  end

  def test_that_disgems_returns_disgemd_records
    refute_includes @user.disgems, @movie
    @user.disgem(@movie)
    assert_includes @user.disgems, @movie
  end

  def test_that_dynamic_disgemd_finder_only_returns_relevant_records
    book = Factory(:book)
    @user.disgem(@movie)
    @user.disgem(book)

    refute_includes @user.disgemd_movies, book
    refute_includes @user.disgemd_books, @movie
  end

  def test_that_disgems_count_counts_all_disgems
    book = Factory(:book)
    movie2 = Factory(:movie)

    @user.disgem(@movie)
    @user.disgem(movie2)
    @user.disgem(book)

    assert_equal @user.disgems_count, 3
  end

  def test_that_dynamic_disgemd_count_methods_only_count_relevant_disgems
    book = Factory(:book)
    movie2 = Factory(:movie)

    @user.disgem(@movie)
    @user.disgem(movie2)
    @user.disgem(book)

    assert_equal @user.disgemd_movies_count, 2
    assert_equal @user.disgemd_books_count, 1
  end

  def test_that_disgems_in_common_with_returns_all_common_disgems
    friend = Factory(:user)
    movie2 = Factory(:movie)
    book = Factory(:book)
    book2 = Factory(:book)

    @user.disgem(@movie)
    @user.disgem(book)
    @user.disgem(movie2)
    friend.disgem(@movie)
    friend.disgem(book)
    friend.disgem(book2)

    assert_includes @user.disgems_in_common_with(friend), @movie
    assert_includes @user.disgems_in_common_with(friend), book
    refute_includes @user.disgems_in_common_with(friend), movie2
    refute_includes friend.disgems_in_common_with(@user), book2
  end

  def test_that_dynamic_disgemd_in_common_with_only_returns_relevant_records
    friend = Factory(:user)
    movie2 = Factory(:movie)
    book = Factory(:book)

    @user.disgem(@movie)
    @user.disgem(book)
    friend.disgem(@movie)
    friend.disgem(book)

    assert_includes @user.disgemd_movies_in_common_with(friend), @movie
    assert_includes @user.disgemd_books_in_common_with(friend), book
    refute_includes @user.disgemd_movies_in_common_with(friend), book
    refute_includes @user.disgemd_books_in_common_with(friend), @movie
  end

  def teardown
    Recommendable.redis.flushdb
  end
end
