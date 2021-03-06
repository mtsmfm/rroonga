# -*- coding: utf-8 -*-
#
# Copyright (C) 2011-2014  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

class DoubleArrayTrieTest < Test::Unit::TestCase
  include GroongaTestUtils
  include ERB::Util

  setup :setup_database

  def test_support_key?
    assert_predicate(Groonga::DoubleArrayTrie.create(:name => "Users",
                                                     :key_type => "ShortText"),
                     :support_key?)
  end

  class SupportValueTest < self
    def test_have_value_type
      assert_predicate(Groonga::DoubleArrayTrie.create(:name => "Users",
                                                       :key_type => "ShortText",
                                                       :value_type => "Int32"),
                       :support_value?)
    end

    def test_no_value_type
      assert_not_predicate(Groonga::DoubleArrayTrie.create(:name => "Users",
                                                           :key_type => "ShortText"),
                           :support_value?)
    end
  end

  def test_encoding
    assert_equal(Groonga::Encoding.default,
                 Groonga::DoubleArrayTrie.create.encoding)
  end

  def test_tokenizer
    trie = Groonga::DoubleArrayTrie.create
    assert_nil(trie.default_tokenizer)
    trie.default_tokenizer = "TokenTrigram"
    assert_equal(Groonga::Context.default["TokenTrigram"],
                 trie.default_tokenizer)
  end

  class TokenFiltersTest < self
    def test_accessor
      context.register_plugin("token_filters/stop_word")
      trie = Groonga::DoubleArrayTrie.create
      assert_equal([], trie.token_filters)
      trie.token_filters = ["TokenFilterStopWord"]
      assert_equal([context["TokenFilterStopWord"]],
                   trie.token_filters)
    end

    def test_create
      context.register_plugin("token_filters/stop_word")
      token_filters = ["TokenFilterStopWord"]
      trie = Groonga::DoubleArrayTrie.create(:token_filters => token_filters)
      assert_equal([context["TokenFilterStopWord"]],
                   trie.token_filters)
    end
  end

  def test_search
    users = Groonga::Array.create(:name => "Users")
    users.define_column("name", "ShortText")

    bookmarks = Groonga::DoubleArrayTrie.create(:name => "Bookmarks",
                                                :key_type => "ShortText")
    bookmarks.define_column("user_id", users)

    daijiro = users.add
    daijiro["name"] = "daijiro"
    gunyarakun = users.add
    gunyarakun["name"] = "gunyarakun"

    groonga = bookmarks.add("http://groonga.org/")
    groonga["user_id"] = daijiro

    records = bookmarks.search("http://groonga.org/")
    assert_equal(["daijiro"],
                 records.records.collect {|record| record[".user_id.name"]})
  end

  def test_add
    users = Groonga::DoubleArrayTrie.create(:name => "Users")
    users.define_column("address", "Text")
    me = users.add("me", :address => "me@example.com")
    assert_equal("me@example.com", me[:address])
  end

  def test_default_tokenizer_on_create
    terms = Groonga::DoubleArrayTrie.create(:name => "Terms",
                                            :default_tokenizer => "TokenUnigram")
    assert_equal(context[Groonga::Type::UNIGRAM],
                 terms.default_tokenizer)
  end

  def test_duplicated_name
    Groonga::DoubleArrayTrie.create(:name => "Users")
    assert_raise(Groonga::InvalidArgument) do
      Groonga::DoubleArrayTrie.create(:name => "Users")
    end
  end

  def test_has_key?
    users = Groonga::DoubleArrayTrie.create(:name => "Users")
    assert_false(users.has_key?("morita"))
    users.add("morita")
    assert_true(users.has_key?("morita"))
  end

  def test_prefix_cursor
    paths = Groonga::DoubleArrayTrie.create(:name => "Paths",
                                            :key_type => 'ShortText')
    paths.add('/')
    paths.add('/tmp')
    paths.add('/usr/bin')
    paths.add('/usr/local/bin')

    assert_prefix_cursor(["/usr/local/bin", "/usr/bin", "/tmp", "/"],
                         paths, "/", {:order => :desc})
    assert_prefix_cursor(["/", "/tmp", "/usr/bin", "/usr/local/bin"],
                         paths, "/")
    assert_prefix_cursor(["/usr/local/bin", "/usr/bin"],
                         paths, "/usr/local",
                         {:key_bytes => "/usr".size, :order => :desc})
    assert_prefix_cursor(["/tmp", "/usr/bin"],
                         paths, "/",
                         {:offset => 1, :limit => 2})
  end

  def assert_prefix_cursor(expected, tables, prefix, options={})
    actual = []
    tables.open_prefix_cursor(prefix, options) do |cursor|
      cursor.each do |record|
        actual << record.key
      end
    end
    assert_equal(expected, actual)
  end

  def test_update_by_key
    users = Groonga::DoubleArrayTrie.create(:name => "Users",
                                            :key_type => "ShortText")
    users.add("Bob")

    users.update("Bob", "Alice")
    assert_equal(["Alice"], users.collect {|user| user.key})
  end

  def test_update_by_id
    users = Groonga::DoubleArrayTrie.create(:name => "Users",
                                            :key_type => "ShortText")
    users.add("Bob")

    users.update(users["Bob"].id, "Alice", :id => true)
    assert_equal(["Alice"], users.collect {|user| user.key})
  end

  def test_add_uint_key
    numbers = Groonga::DoubleArrayTrie.create(:name => "Numbers",
                                              :key_type => "UInt32")
    numbers.add(1)
    numbers.add(2)
    numbers.add(5)
    numbers.add(7)
    assert_equal([1, 2, 5, 7], numbers.collect {|number| number.key})
  end

  def test_added?
    users = Groonga::DoubleArrayTrie.create(:name => "Users",
                                            :key_type => "ShortText")
    bob = users.add("bob")
    assert_predicate(bob, :added?)
    bob_again = users.add("bob")
    assert_not_predicate(bob_again, :added?)
  end

  def test_defrag
    users = Groonga::DoubleArrayTrie.create(:name => "Users",
                                            :key_type => "ShortText")
    users.define_column("name", "ShortText")
    users.define_column("address", "ShortText")
    large_data = "x" * (2 ** 16)
    100.times do |i|
      users.add("user #{i}",
                :name => "user #{i}" + large_data,
                :address => "address #{i}" + large_data)
    end
    assert_equal(2, users.defrag)
  end

  def test_rename
    users = Groonga::DoubleArrayTrie.create(:name => "Users",
                                            :key_type => "ShortText")
    name = users.define_column("name", "ShortText")
    address = users.define_column("address", "ShortText")

    users.rename("People")
    assert_equal(["People", "People.name", "People.address"],
                 [users.name, name.name, address.name])
  end

  def test_each
    users = Groonga::DoubleArrayTrie.create(:name => "Users",
                                            :key_type => "ShortText")
    users.add("Alice")
    users.add("Bob")
    users.add("Carl")

    user_names = []
    users.each do |user|
      user_names << user.key
    end
    assert_equal(["Alice", "Bob", "Carl"], user_names)
  end

  def test_each_without_block
    users = Groonga::DoubleArrayTrie.create(:name => "Users",
                                            :key_type => "ShortText")
    users.add("Alice")
    users.add("Bob")
    users.add("Carl")

    user_names = users.each.collect(&:key)
    assert_equal(["Alice", "Bob", "Carl"], user_names)
  end
end
