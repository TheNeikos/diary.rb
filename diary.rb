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
require 'find'
require 'ostruct'
require 'fileutils'

class Config < Hash

  # defaults
  def initialize(other_config = Hash.new)
    self[:root] = Dir.home + "/.diary"
    self[:cfg] = self[:root] + "/diary.conf"

    self.merge other_config
  end

  def []=(k, v)
    super[k.to_sym] = v
  end

  def [](k)
    super[k.to_sym]
  end

end

class Options < Hash
  def []=(k, v)
    k = non_arg k
    key, value = parse(k, v)
    super[key] = value
  end

  def [](k)
    super[non_arg(k)]
  end

  protected

  def non_arg(str)
    str.gsub(/^--/, "")
  end

  def parse(key, value)
    if key.include? "="
      key = key.split("=").first
      value = { key.split("=")[1] => value }
    end

    [key, value]
  end

end

module ConfigReader

  def config=(c)
    raise "Not a configuration: #{c.class} : #{c}" unless c.is_a? Config
    @config = c
  end

end

class Entry
  include ConfigReader

  attr_accessor :time
  attr_reader :content, :raw

  def initialize(time, content)
    @time = time
    @content = content.encode(Encoding::UTF_8)
    @raw = content
  end

end

class Day
  include ConfigReader

  attr_accessor :entries

  def initialize(entries)
    @entries = entries
  end

end

class Month
  include ConfigReader

  attr_accessor :days
  attr_reader :month_index

  def initialize(days, month_index = false)
    @month_index = month_index || Date.today.month
    @days = days
  end

  def name
    Date::MONTHNAMES[@month_index].downcase
  end

end

class Year
  include ConfigReader

  attr_accessor :months

  def initialize(months, y = false)
    @year = y || Date.today.year
    @months = months
  end

end
