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
require 'digest/sha512'

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

  module CommandParser

    module ExecuteableCommand

      def action(tree)
        raise NoMethodException.new "Not implemented"
      end

    end

    class Command
      attr_reader :keys, :attributes

      @expected_attr_count = [] # all valid command attribute numbers, can be a range
      @keys = []
      @attributes = []

      def expected_attr_count
        if self.class == Command
          @expected_attr_count
        else
          super.expected_attr_count + @expected_attr_count
        end
      end

      def add_attribute a
        @attributes << a
      end

      def self.is_command? str
        ["-", "+"].map { |e| str.start_with? e }.any?
      end

      def self.assign_cmd? str
        str.include? "="
      end

    end


    class QueryCommand < Command
    end

    class CatCommand < QueryCommand
    end

    class CatLastCommand < CatCommand
    end

    class LimitCommand < QueryCommand
    end

    class LimitRangeCommand < LimitCommand
    end


    class LimitInCommand < LimitCommand
    end

    class LimitYearCommand < LimitInCommand
    end

    class LimitMonthCommand < LimitInCommand
    end

    class LimitDayCommand < LimitInCommand
    end


    class FilterCommand < QueryCommand

      def filter_tree(tree)
        tree
      end

    end

    class TagFilterCommand < FilterCommand

      @expected_attr_count = [ 0 ]

      def initialize(name)
        @tagname = name
      end

      # Take
      #
      #   1) All entries which are tagged
      #
      #   2) All days and its entries which are tagged
      #
      #   3) All months, its days and its entries which are tagged
      #
      #   4) All years, its months and days and entries which are tagged
      #
      # After that we remove the entries, days, months and years (in this order)
      # from the tree, to ensure entries which are kept, are also kept if the
      # appropriate year for the entry is not kept
      #
      def filter_tree tree
        years = filter_years tree.years
        months = filter_months(tree.years.select { |y| not years.include? y })
        days = filter_days(months.select { |m| not months.include? m })
        entries = filter_entries(days.select { |d| not days.include? d })

        # throw out the entries
        tree.keep_entries entries

        # then the days
        tree.keep_days days

        # then all other months
        tree.keep_months months

        # then all other years
        tree.keep_years years

        tree
      end

      protected

      def filter(ary, meth)
        ary.map(&meth).flatten.select { |x| x.tags.include? @tagname }
      end

      def filter_years tree
        filter([tree], :years)
      end

      def filter_months(years)
        filter(years, :month)
      end

      def filter_days(months)
        filter(months, :days)
      end

      def filter_entries(days)
        filter(days, :entries)
      end

    end

    class CategoryFilterCommand < FilterCommand
    end


    class ModifyCommand < Command
    end

    class EditCommand < ModifyCommand
    end

    class TagCommand < ModifyCommand
    end

    class CategorizeCommand < ModifyCommand
    end


    class AddCommand < Command
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
    attr_reader :content, :raw, :hash

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

    def hash
      @hash ||= Digest::SHA512.hexdigest @raw
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

  class Tree
    include CreateAbleFromPath
    include Iterateable

    @years = []

    def self.from_path(path,  create_subs = false)
      @path = path

      if create_subs
        @years = self.subs_from_path(path, Year, lambda { |e| File.directory? e })
      end
    end

    def keep_entries entries
      @years.each do |year|
        year.months.each do |month|
          month.days.each do |day|
            day.entries.delete_if { |e| not entries.include? e }
          end
        end
      end
    end

    def keep_days days
      @years.each do |year|
        year.months.each do |month|
          month.days.delete_if { |d| not days.include? d }
        end
      end
    end

    def keep_months months
      @years.each do |year|
        year.months.delete_if { |m| not months.include? m }
      end
    end

    def keep_years years
      @years.delete_if { |y| not years.include? y }
    end

  end

end
