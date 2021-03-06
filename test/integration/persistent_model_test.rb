require 'test_helper'

module Tire

  class PersistentModelIntegrationTest < Test::Unit::TestCase
    include Test::Integration

    def setup
      super
      PersistentArticle.index.delete
    end

    def teardown
      super
      PersistentArticle.index.delete
      PersistentArticleWithDefaults.index.delete
    end

    context "PersistentModel" do
      should "search with simple query" do
        PersistentArticle.create :id => 1, :title => 'One'
        PersistentArticle.index.refresh

        results = PersistentArticle.search 'one'
        assert_equal 'One', results.first.title
      end

      should "search with a block" do
        PersistentArticle.create :id => 1, :title => 'One'
        PersistentArticle.index.refresh

        results = PersistentArticle.search(:sort => 'title') { query { string 'one' } }
        assert_equal 'One', results.first.title
      end

      should "return instances of model" do
        PersistentArticle.create :id => 1, :title => 'One'
        PersistentArticle.index.refresh

        results = PersistentArticle.search 'one'
        assert_instance_of PersistentArticle, results.first
      end

      should "save documents into index and find them by IDs" do
        one = PersistentArticle.create :id => 1, :title => 'One'
        two = PersistentArticle.create :id => 2, :title => 'Two'

        PersistentArticle.index.refresh

        results = PersistentArticle.find [1, 2]

        assert_equal 2, results.size
      end

      should "be persisted" do
        one = PersistentArticle.create :id => 1, :title => 'One'
        PersistentArticle.index.refresh

        a = PersistentArticle.all.first
        assert a.persisted?, a.inspect

        b = PersistentArticle.first
        assert b.persisted?, b.inspect

        c = PersistentArticle.search { query { string 'one' } }.first
        assert c.persisted?, c.inspect
      end

      should "return default values for properties without value" do
        PersistentArticleWithDefaults.create :id => 1, :title => 'One'
        PersistentArticleWithDefaults.index.refresh

        results = PersistentArticleWithDefaults.all

        assert_equal [], results.first.tags
      end

      context "with pagination" do

        setup do
          1.upto(9) { |number| PersistentArticle.create :title => "Test#{number}" }
          PersistentArticle.index.refresh
        end

        should "find first page with five results" do
          results = PersistentArticle.search( :per_page => 5, :page => 1 ) { query { all } }
          assert_equal 5, results.size

          # WillPaginate
          #
          assert_equal 2, results.total_pages
          assert_equal 1, results.current_page
          assert_equal nil, results.previous_page
          assert_equal 2, results.next_page

          # Kaminari
          #
          assert_equal 5, results.limit_value
          assert_equal 9, results.total_count
          assert_equal 2, results.num_pages
          assert_equal 0, results.offset_value
        end

      end

      context "with namespaced models" do
        setup do
          MyNamespace::PersistentArticleInNamespace.create :title => 'Test'
          MyNamespace::PersistentArticleInNamespace.index.refresh
        end

        teardown do
          MyNamespace::PersistentArticleInNamespace.index.delete
        end

        should "find the document in the index" do
          results = MyNamespace::PersistentArticleInNamespace.search 'test'

          assert       results.any?, "No results returned: #{results.inspect}"
          assert_equal 1, results.count

          assert_instance_of MyNamespace::PersistentArticleInNamespace, results.first
        end

      end

      context "with multiple types within single index" do

        setup do
          # Create documents of two types within single index
          1.upto(3) { |number| PersistentArticleInIndex.create :title => "TestInIndex#{number}", :tags => ['in_index'] }
          1.upto(3) { |number| PersistentArticle.create :title => "Test#{number}", :tags => [] }
          PersistentArticle.index.refresh
        end

        should "returns all documents with proper type" do
          results = PersistentArticle.all

          assert_equal 3, results.size
          assert results.all? { |r| r.tags == [] }, "Incorrect results:" + results.to_a.inspect

          results = PersistentArticleInIndex.all

          assert_equal 3, results.size
          assert_equal ['in_index'], results.first.tags
        end

        should "returns first document with proper type" do
          assert_equal [], PersistentArticle.first.tags
          assert_equal ['in_index'], PersistentArticleInIndex.first.tags
        end
      end

    end

  end
end
