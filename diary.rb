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

module Diary

  class Config < Hash

    # defaults
    def initialize(other_config_path = false)
      self[:root] = Dir.home + "/.diary"
      self[:content_dir] = self[:root] + "/content"
      self[:configfile] = other_config_path || self[:root] + "/diary.conf"
      self[:editor] = "/usr/bin/vi"

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
      # TODO: read self[:configfile] file to hash and return
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

  module CreateAbleFromPath

    attr_reader :path

    def self.from_path(path)
      raise NoMethodException.new("Not implemented")
    end

    def self.subs_from_path(path, gen_class, &block)
      Dir.new(path).entries.select(&block).map do |entry|
        gen_class.from_path(path + "/" + entry, true)
      end
    end

  end

  module Indexable

    attr_reader :index

    def index_str(n = 2)
      @index.to_s.rjust(n, "0")
    end

    def self.index_from_path(path, regex)
      path.match(regex).to_s.to_i
    end

  end

  module Iterateable

    def each &block
      raise NoMethodException.new("Not implemented")
    end

  end

  class Entry
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
      time = self.time_from_path(path)
      raw = File.read path

      Entry.new(time, raw)
    end

    protected

    def self.time_from_path(path)
      Time.parse path.match(/[0-2][0-9]-[0-9]{2,2}-[0-9]{2,2}/).to_s
    end

  end

  class Day
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

    def self.from_path(path, create_subs = false)
      @index = self.index_from_path(path, /[0-9]{2,2}$/)
      if create_subs
        @entries = self.subs_from_path(path, Entry, lambda { |e| File.file? e })
      end
    end

  end

  class Month
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
      Date::MONTHNAMES[@index].downcase
    end

    def self.from_path(path, create_subs = false)
      @index = self.index_from_path(path, /[0-9]{2,2}$/)
      if create_subs
        @days = self.subs_from_path(path, Day, lambda { |e| File.directory? e })
      end
    end

  end

  class Year
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

    def self.from_path(path, create_subs = false)
      @path = path
      @year = self.year_from_path path
      if create_subs
        @months = self.subs_from_path(path, Month, lambda { |e| File.directory? e })
      end
    end

    protected

    def self.year_from_path path
      path.match(/[0-9]{4,4}$/).to_s.to_i
    end

  end

end
