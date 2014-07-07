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

require './array/array.rb'
require './enumerator/lazy.rb'

require './config.rb'
require './commands.rb'
require './tree_elements/tree_element.rb'
require './tree_elements/day.rb'
require './tree_elements/month.rb'
require './tree_elements/year.rb'
require './tree_elements/tree.rb'
require './iterateable.rb'

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

