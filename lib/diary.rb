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

require './diary/override/array.rb'
require './diary/enumerator/lazy.rb'

require './diary/config.rb'
require './diary/commands.rb'
require './diary/tree_elements/tree_element.rb'
require './diary/tree_elements/day.rb'
require './diary/tree_elements/month.rb'
require './diary/tree_elements/year.rb'
require './diary/tree_elements/tree.rb'
require './diary/iterateable.rb'

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

