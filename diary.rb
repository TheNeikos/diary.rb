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

    module ExtendedQueryCommand
      # nothing yet
      #
      # shows that a command can be executed _before_ actually parsing the file
      # tree
    end

    module ConfigReaderCommand

      def config=(cfg)
        @config = cfg
      end

    end

    module InstanceAbleCommand
      attr_reader :noncompatible_commands

      # All Not Compatible commands, can be superclass of own class
      @@noncompatible_commands = []
    end

    # Commands which have an effect on the _reading_ of the tree should contain
    # this module
    module ReaderCommand
    end

    class Command
      attr_reader :keys, :attributes

      @expected_attr_count = [] # all valid command attribute numbers, can be a range
      @@keys = []
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
      include InstanceAbleCommand
      include ExecuteableCommand

      @@noncompatible_commands = [ QueryCommand ]

      @expected_attr_count = [0, 1]
      @keys = ["--cat", "-c"]

      def action(tree)
        tree.each do |entry|
          cat entry
          puts ""
        end
      end

      protected

      def cat(entry)
        if @attributes.include? "raw"
          puts entry.raw
        else
          puts "--- #{entry.time}"
          puts entry.content
        end
      end

    end

    class CatLastCommand < CatCommand
      include ExecuteableCommand
      include ExtendedQueryCommand
      include ConfigReaderCommand

      @@noncompatible_commands = [ QueryCommand ]

      def action(tree)
        # `tree` should be empty, as this command is also a query command

        year_path   = latest_year
        month_path  = latest_sub_path year_path
        day_path    = latest_sub_path month_path
        entry_path  = latest_sub_path day_path

        cat entry_path
      end

      protected

      def latest_year
        latest_sub_path @config[:content_dir]
      end

      def latest_sub_path(base)
        entries = Dir.new(base).entries
        ibase = entries.map(&:to_i)
        base + "/" + entries[ibase.index(ibase.max)]
      end

    end

    class LimitCommand < QueryCommand

      def search_in?(path)
        true
      end

    end

    class LimitRangeCommand < LimitCommand
      include InstanceAbleCommand
      include ReaderCommand

      @@noncompatible_commands = [ LimitCommand ]

      @expected_attr_count = [ 1 ] # only one
      @keys = [ "--between", "-b" ]

      # override
      def add_attribute a
        super.add_attribute a
        parse_attribute a
      end

      def search_in? path
        fmt = ""
        fmt << "%Y/" if @start_year  || @end_year
        fmt << "%m/" if @start_month || @end_month
        fmt << "%d/" if @start_day   || @end_day

        d = Date.strptime(path, fmt)
        (@start_date..@end_date).include? d
      end

      protected

      def parse_attribute a
        start_date = a.split("..").first
        end_date = a.split("..").last

        parse_start_date start_date
        parse_start_date end_date
      end

      def parse_start_date start_date
        @start_year, @start_month, @start_day = parse_date start_date
        @start_date = Date.parse("#{@start_year}-#{@start_month}-#{@start_day}")
      end

      def parse_end_date end_date
        @end_year, @end_month, @end_day = parse_date end_date
        @end_date = Date.parse("#{@end_year}-#{@end_month}-#{@end_day}")
      end

      def parse_date str
        y, m, d = [nil, nil, nil]

        parts = str.split("-")
        nparts = parts.length

        if nparts > 3 or nparts < 1
          # something wents wrong
          puts "Huh, date parsing fails"
          raise "Date parsing went wrong, your date has not [1,2,3] parts"
        end

        d = parts.pop.to_i if nparts == 3
        m = parts.pop.to_i if nparts <= 2
        y = parts.pop.to_i if nparts <= 1

        [y, m || 1, d || 1]
      end

    end


    class LimitInCommand < LimitRangeCommand
      include InstanceAbleCommand
      include ReaderCommand

      @@noncompatible_commands = [ LimitCommand ]

      # override
      def search_in? path
        if @start_year and not path.include? @start_year.to_s
          return false
        end

        if @start_month and not path.include? "#{@start_year}/#{@start_month}"
          return false
        end

        if @start_day and not path.include? "#{@start_year}/#{@start_month}/#{@start_day}"
          return false
        end

        return true
      end

      protected

      # override
      def parse_attribute a
        # we only parse the start date here, as we only have one date.
        parse_start_date a
      end

    end

    class LimitYearCommand < LimitInCommand
      include InstanceAbleCommand
      include ReaderCommand

      @@noncompatible_commands = [ LimitRangeCommand, LimitInCommand ]

      @expected_attr_count = [ 1 ]
      @keys = [ "--year" ]
      @attributes = []

      def search_in? path
        y = @attribute.first

        path.match(/#{y.to_s}\/[0-9]{2,2}\/[0-9]{2,2}\//)
      end

    end

    class LimitMonthCommand < LimitInCommand
      include InstanceAbleCommand
      include ReaderCommand

      @@noncompatible_commands = [ LimitRangeCommand, LimitInCommand ]

      @expected_attr_count = [ 1 ]
      @keys = [ "--year" ]
      @attributes = []

      def search_in? path
        m = @attribute.first

        path.match(/[0-9]{4,4}\/#{m}\/[0-9]{2,2}\//)
      end

    end

    class LimitDayCommand < LimitInCommand
      include InstanceAbleCommand
      include ReaderCommand

      @@noncompatible_commands = [ LimitRangeCommand, LimitInCommand ]

      @expected_attr_count = [ 1 ]
      @keys = [ "--year" ]
      @attributes = []

      def search_in? path
        d = @attribute.first

        path.match(/[0-9]{4,4}\/[0-9]{2,2}\/#{d}\//)
      end

    end


    class FilterCommand < QueryCommand

      def filter_tree(tree)
        tree
      end

      # Take
      #
      #   1) All entries which have the attribute
      #
      #   2) All days and its entries which have the attribute
      #
      #   3) All months, its days and its entries which have the attribute
      #
      #   4) All years, its months and days and entries which have the attribute
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
        raise NoMethodException.new "Not implemented"
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

    class TagFilterCommand < FilterCommand
      include InstanceAbleCommand

      @expected_attr_count = [ 0 ]

      def initialize(name)
        @tagname = name
      end

      protected

      # override
      def filter(ary, meth)
        ary.map(&meth).flatten.select { |x| x.tags.include? @tagname }
      end

    end

    class CategoryFilterCommand < FilterCommand
      include InstanceAbleCommand

      def initialize(name)
        @catname = name
      end

      protected

      # override
      def filter(ary, meth)
        ary.map(&meth).flatten.select { |x| x.categories.include? @catname }
      end

    end


    class ModifyCommand < Command
    end

    class EditCommand < ModifyCommand
      include InstanceAbleCommand

      @@noncompatible_commands = [ LimitCommand, FilterCommand,
                                  ModifyCommand, AddCommand ]
    end

    class TagCommand < ModifyCommand
      include InstanceAbleCommand

      @@noncompatible_commands = [ EditCommand ]
    end

    class CategorizeCommand < ModifyCommand
      include InstanceAbleCommand

      @@noncompatible_commands = [ EditCommand ]
    end


    class AddCommand < Command
      include InstanceAbleCommand
      include ExecuteableCommand

      @@noncompatible_commands = [ Command ] # either add or something else.

      def action(tree)
        dir = generate_dir_path
        ensure_dir_exists dir
        path = generate_full_path dir
        touch path
        call_editor path
      end

      protected

      def generate_dir_path
        Time.now.strftime "%Y/%m/%d"
      end

      def generate_full_path(dirpath)
        dirpath + Time.now.strftime("%H-%m-%S")
      end

      def touch path
        FileUtils.touch path
      end

      def call_editor path
        # TODO
      end

    end


    class Parser

      attr_reader :commands

      def initialize(argv)
        @argv = argv
        @commands = []
      end

      def parse!
        next_command! until @argv.empty?
      end

      def available_commands
        [
          Command,
          QueryCommand,
          CatCommand,
          CatLastCommand,
          LimitCommand,
          LimitRangeCommand,
          LimitInCommand,
          LimitYearCommand,
          LimitMonthCommand,
          LimitDayCommand,
          FilterCommand,
          TagFilterCommand,
          CategoryFilterCommand,
          ModifyCommand,
          EditCommand,
          TagCommand,
          CategorizeCommand,
          AddCommand
        ].select { |s| s.is_a? InstanceAbleCommand }
      end

      protected

      def next_command!
        cmd = @argv.pop
        raise "Not a command: #{cmd}" if not Command.is_command? cmd

        commands = available_commands.select { |c| c.keys.include? cmd }

        if commands.length.zero?
          puts "Command not found: #{cmd}"
          exit 1
        end

        if commands.length > 1
          puts "Command seems to be not unique: #{cmd}"
          exit 1
        end

        @commands << create_instance!(commands.first)
      end

      def create_instance!(c)
        # decide which class this is, create the appropriate instance
        instance = nil # TODO

        i = instance.expected_attr_count
        until i == 0 |n|
          instance.add_attribute(@argv.pop)
          i -= 1
        end

        raise "Possibly not enough arguments for #{c}" if not i.zero?
        instance
      end

    end

  end

  class Executer

    def initalize(config, commands)
      @config = config
      @commands = commands
      raise "Invalid command state..." if not valid?
    end

    def execute!
    end

    protected

    def valid?
      commands_compatible?
    end

    def commands_compatible?
      @commands.each do |command|
        @commands.each do |other|
          return false if command.class.noncompatible_commands.include? other
        end
      end

      return true
    end

    def reader_commands
      only_commands ReaderCommand
    end

    def filter_commands
      only_commands FilterCommand
    end

    def limit_commands
      only_commands LimitCommand
    end

    def query_commands
      only_commands QueryCommand
    end

    def only klass
      @commands.select { |c| c.is_a? klass }
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
