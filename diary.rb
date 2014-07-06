#!/usr/bin/env ruby

#
# diary.rb
# ========
#
# Dependency-less clone of the awesome shell script "diary" which can be found
# here:
#
#   http://sourceforge.net/projects/diary/
#
# This version won't be compatible anymore.
#
# All loaded libraries should be shipped with ruby itself. So there is no need
# to install any gem to run this script.
#

require 'yaml'
require 'optparse'
require 'date'
require 'time'
require 'find'
require 'ostruct'
require 'fileutils'
require 'digest'
require 'digest/sha2'
require 'json'

require './config.rb'
require './commands.rb'
require './tree_elements.rb'

class Array

  def includes_any? other
    other.lazy.map { |o| self.include? o }.any?
  end

end

class Enumerator::Lazy

  def any_or_none?
    self.entries.empty? or self.entries.any?
  end

end

module Diary

  module Iterateable

    def each &block
      raise NoMethodException.new("Not implemented")
    end

  end



  class Executer

    def initialize(commands, config)
      @config = config
      @commands = commands
      raise "Invalid command state..." if not valid?
    end

    def execute!
      try_precommands and exit 0

      tree = build_tree
      tree = filter_tree(tree, filter_commands)

      run_queries(tree, query_commands)
    end

    protected

    def try_precommands
      pre_commands.each do |pre|
        c = @commands.select { |cmd| cmd.is_a? pre }
        return (!!c.first.action([])) if c.one?
      end
      false
    end

    def build_tree
      Tree.from_path(@config[:content_dir], reader_commands)
    end

    def run_queries(tree, queries)
      queries << CommandParser::ListCommand.new if queries.empty?
      queries.each { |qcmd| qcmd.action(tree) }
    end

    def valid?
      commands_compatible?
    end

    def commands_compatible?
      not @commands.lazy.map do |cmd|
        cmd.class.noncompatible_commands.includes_any? (@commands - [cmd])
      end.any?
    end

    def filter_tree(tree, commands)
      tree
    end

    def reader_commands
      only_commands CommandParser::ReaderCommand
    end

    def filter_commands
      only_commands CommandParser::FilterCommand
    end

    def limit_commands
      only_commands CommandParser::LimitCommand
    end

    def query_commands
      only_commands CommandParser::QueryCommand
    end

    def only_commands klass
      @commands.select { |c| c.is_a? klass }
    end

    def pre_commands
      [
        CommandParser::HelpCommand,
        CommandParser::ListCommand,
        CommandParser::AddCommand
      ]
    end

  end

end

if __FILE__ == $0
  config = {
    :debug => true,
    :root => "/tmp",
    :content_dir => "/tmp/content",
  }
  cp = Diary::CommandParser::Parser.new(ARGV, config)
  cp.parse!

  ex = Diary::Executer.new(cp.commands, config)
  ex.execute!
end
