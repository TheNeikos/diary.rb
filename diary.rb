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

class Config < Hash

  # defaults
  def initialize(other_config_path = false)
    self[:root] = Dir.home + "/.diary"
    self[:content_dir] = self[:root] + "/content"
    self[:cfg] = other_config_path || self[:root] + "/diary.conf"

    self[:ext] = "txt"

    self.merge non_default_config
  end

  def []=(k, v)
    super[k.to_sym] = v
  end

  def [](k)
    super[k.to_sym]
  end

  protected

  def non_default_config
    # TODO: read self[:cfg] file to hash and return
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

module CreateAbleFromPath

  attr_reader :path

  def self.from_path(path)
    raise NoMethodException.new("Not implemented")
  end

end

module Indexable

  attr_reader :index

  def index_str(n = 2)
    @index.to_s.rjust(n, "0")
  end

end

module Iterateable

  def each &block
    raise NoMethodException.new("Not implemented")
  end

end

class Entry
  include ConfigReader
  include CreateAbleFromPath
  include Indexable

  attr_accessor :time
  attr_reader :content, :raw

  def initialize(time, content)
    @time = time
    @content = content.encode(Encoding::UTF_8)
    @raw = content
  end

  def self.from_path(path)
    @time = self.time_from_path(path)
    @raw = File.read path
    @content = @raw.encode(Encoding::UTF_8)
  end

  protected

  def self.time_from_path(path)
    Time.parse path.match(/[0-2][0-9]-[0-9]{2,2}-[0-9]{2,2}/).to_s
  end

end

class Day
  include ConfigReader
  include CreateAbleFromPath
  include Indexable
  include Iterateable

  attr_accessor :entries

  def initialize(entries, day_index = false)
    @index = day_index || Date.today.day
    @entries = entries
  end

  def each &block
    @entries.each(&block)
  end

  def self.from_path(path)
    @index = self.index_from_path(path)
    @entries = self.entries_from_path(path)
  end

  protected

  def self.index_from_path(path)
    path.match(/[0-9]{2,2}$/).to_s.to_i
  end

  def self.entries_from_path(path)
    Dir.new(path).entries.select { |sub| File.file? sub }.map do |entry|
      Entry.from_path(path + "/" + entry)
    end
  end

end

class Month
  include ConfigReader
  include CreateAbleFromPath
  include Indexable
  include Iterateable

  attr_accessor :days

  def initialize(days, month_index = false)
    @index = month_index || Date.today.month
    @days = days
  end

  def each &block
    @days.each(&block)
  end

  def name
    Date::MONTHNAMES[@month_index].downcase
  end

  def self.from_path(path)
    @index = self.index_from_path(path)
    @days = self.days_from_path(path)
  end

  protected

  def self.index_from_path(path)
    path.match(/[0-9]{2,2}$/).to_s.to_i
  end

  def self.days_from_path(path)
    Dir.new(path).entries.select { |sub| File.directory? sub }.map do |day|
      Day.from_path(path + "/" + day)
    end
  end

end

class Year
  include ConfigReader
  include CreateAbleFromPath
  include Iterateable

  attr_accessor :months

  def initialize(months, y = false)
    @year = y || Date.today.year
    @months = months
  end

  def each &block
    @months.each(&block)
  end

  def self.from_path(path)
    @path = path
    @year = self.year_from_path path
    @months = self.months_under path
  end

  protected

  def self.year_from_path path
    path.match(/[0-9]{4,4}$/).to_s.to_i
  end

  def self.months_undex path
    Dir.new(path).entries.select { |sub| File.directory? sub }.map do |month|
      Month.from_path(path + "/" + month)
    end
  end

end
