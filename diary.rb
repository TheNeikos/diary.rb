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
