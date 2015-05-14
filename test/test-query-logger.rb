# Copyright (C) 2015  Kouhei Sutou <kou@clear-code.com>
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

class QueryLoggerTest < Test::Unit::TestCase
  include GroongaTestUtils

  def setup
    @default_log_path = Groonga::QueryLogger.path
  end

  def teardown
    Groonga::QueryLogger.path = @default_log_path
  end

  def test_reopen
    Groonga::QueryLogger.unregister
    Groonga::QueryLogger.path = @query_log_path.to_s
    if @query_log_path.exist?
      FileUtils.mv(@query_log_path, "#{@query_log_path}.old")
    end
    assert do
      not @query_log_path.exist?
    end
    Groonga::QueryLogger.reopen
    assert do
      @query_log_path.exist?
    end
  end

  sub_test_case ".parse" do
    def parse(input, base_flags=nil)
      base_flags ||= Groonga::QueryLogger::Flags::NONE
      Groonga::QueryLogger::Flags.parse(input, base_flags)
    end

    test "nil" do
      assert_equal(Groonga::QueryLogger::Flags::NONE,
                   parse(nil))
    end

    test "Integer" do
      assert_equal(Groonga::QueryLogger::Flags::COMMAND,
                   parse(Groonga::QueryLogger::Flags::COMMAND))
    end

    test "String" do
      assert_equal(Groonga::QueryLogger::Flags::COMMAND,
                   parse("command"))
    end

    test "Symbol" do
      assert_equal(Groonga::QueryLogger::Flags::COMMAND,
                   parse(:command))
    end

    test "Array" do
      assert_equal(Groonga::QueryLogger::Flags::COMMAND |
                   Groonga::QueryLogger::Flags::RESULT_CODE,
                   parse([:command, :result_code]))
    end

    test "Hash" do
      assert_equal(Groonga::QueryLogger::Flags::COMMAND |
                   Groonga::QueryLogger::Flags::DESTINATION,
                   parse({
                           :command => true,
                           :result_code => false,
                           :destination => true,
                         },
                         Groonga::QueryLogger::Flags::COMMAND |
                         Groonga::QueryLogger::Flags::RESULT_CODE))
    end
  end

  sub_test_case ".log" do
    test "no options" do
      messages = []
      Groonga::QueryLogger.register do |action, flag, timestamp, info, message|
        messages << message
      end
      Groonga::QueryLogger.log("1")
      Groonga::QueryLogger.log("2")
      Groonga::QueryLogger.log("3")
      assert_equal(["1", "2", "3"],
                   messages)
    end

    test ":mark" do
      infos = []
      Groonga::QueryLogger.register do |action, flag, timestamp, info, message|
        infos << info
      end
      Groonga::QueryLogger.log("default")
      Groonga::QueryLogger.log("mark", :mark => ":")
      normalized_infos = infos.collect do |info|
        info.gsub(/\A0x[a-f\d]+\|([^\d])?[\d]+ \z/,
                  "context_id|\\1timestamp ")
      end
      assert_equal([
                     "context_id|timestamp ",
                     "context_id|:timestamp ",
                   ],
                   normalized_infos)
    end
  end
end