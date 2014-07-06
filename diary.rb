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


class Array

  def includes_any? other
    other.lazy.map { |o| self.include? o }.any?
  end

end

module Diary

  class Config < Hash

    # defaults
    def initialize(other_config_path = false)
      self[:root]         = Dir.home + "/.diary"
      self[:content_dir]  = self[:root] + "/content"
      self[:configfile]   = other_config_path || self[:root] + "/diary.conf"
      self[:editor]       = "/usr/bin/vi"
      self[:ext]          = "txt"

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

    # Commands which are able to be instanciated and then executed should
    # include this module
    module InstanceAbleCommand
    end

    # Commands which have an effect on the _reading_ of the tree should contain
    # this module
    module ReaderCommand
    end

    # If a command is only able to appear once, include this module
    module Uniqueness

      def uniqueness
        true
      end

    end

    class Command
      attr_reader :keys, :attributes

      def initialize
        @attributes = []
      end

      def add_attribute a
        @attributes ||= []
        @attributes << a
      end

      def self.is_command? str
        ["-", "+"].map { |e| str.start_with? e }.any?
      end

      def self.def_returner(name, obj)
        define_singleton_method name do
          obj
        end
      end

      # fancy meta-programming for generating :keys method on the fly
      def self.with_keys ks
        def_returner :keys, ks
      end

      # fancy meta-programming for generating :help method on the fly
      def self.with_help str
        def_returner :help, str
      end

      # fancy meta-programming for generating :noncompatible_commands method on
      # the fly.
      #
      # All Not Compatible commands, can be superclass of own class
      def self.not_compatible_to ary
        def_returner :noncompatible_commands, ary
      end

      # fancy meta-programming for generating the #expected_attr_count meth
      def self.expects_nattrs range
        def_returner :expected_attr_count, range
      end

    end


    class HelpCommand < Command
      include InstanceAbleCommand
      include ReaderCommand

      with_keys ["-h", "--help"]
      with_help "Print the help and exit"

      def action(tree)
        CommandParser.constants.select do |c|
          c.is_a? CommandParser::Command and c.is_a? InstanceAbleCommand
        end.sort.each do |c|
          puts "#{c.keys.join(", ")}\t#{c.help}"
        end

        exit 1
      end

    end


    class QueryCommand < Command
    end

    class ListCommand < QueryCommand
      include InstanceAbleCommand
      include Uniqueness

      not_compatible_to [ QueryCommand ]

      with_keys ["--list"]
      with_help "List entries only"

      expects_nattrs (0..0)


      def action(tree)
        tree.all_entries.each do |entry|
          puts "[#{entry.hash}] #{entry.time}"
        end
      end
    end

    class CatCommand < QueryCommand
      include InstanceAbleCommand
      include ExecuteableCommand
      include Uniqueness

      not_compatible_to [ QueryCommand ]

      expects_nattrs (0..1)

      with_keys ["--cat", "-c"]
      with_help "Print entries"

      def action(tree)
        tree.each do |y|
          y.each do |m|
            m.each do |d|
              d.each do |entry|
                cat entry
                puts ""
              end
            end
          end
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
      include Uniqueness

      not_compatible_to [ QueryCommand ]

      with_keys ["--last", "-l"]

      expects_nattrs (0..0)

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

      not_compatible_to [ LimitCommand ]

      with_keys [ "--between", "-b" ]
      with_help "Limit the search-range to a range. Ex.: 2013..2014 or 2013-01..2013-02"

      expects_nattrs (1..1) # only one

      # override
      alias super_add_attribute add_attribute
      def add_attribute a
        super_add_attribute a
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
        parse_end_date end_date
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
        m = parts.pop.to_i if nparts >= 2
        y = parts.pop.to_i if nparts >= 1

        [y, m || 1, d || 1]
      end

    end


    class LimitInCommand < LimitRangeCommand
      include InstanceAbleCommand
      include ReaderCommand

      not_compatible_to [ LimitCommand ]

      with_keys ["--limit-in"]
      with_help "Limit search for a year, year-month or year-month-day"

      expects_nattrs (0..0)

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

      not_compatible_to [ LimitRangeCommand, LimitInCommand ]

      with_keys [ "--year" ]
      with_help "Limit search for a certain year, multiple possible"

      expects_nattrs (1..1)

      @attributes = []

      def search_in? path
        y = @attribute.first

        path.match(/#{y.to_s}\/[0-9]{2,2}\/[0-9]{2,2}\//)
      end

      protected

      # override
      def parse_attribute a
        # nothing
      end

    end

    class LimitMonthCommand < LimitInCommand
      include InstanceAbleCommand
      include ReaderCommand

      not_compatible_to [ LimitRangeCommand, LimitInCommand ]

      with_keys [ "--month" ]
      with_help "Limit search for a certain Month, multiple possible. Does not filter years"

      expects_nattrs (1..1)

      @attributes = []

      def search_in? path
        m = @attribute.first

        path.match(/[0-9]{4,4}\/#{m}\/[0-9]{2,2}\//)
      end

      protected

      # override
      def parse_attribute a
        # nothing
      end

    end

    class LimitDayCommand < LimitInCommand
      include InstanceAbleCommand
      include ReaderCommand

      not_compatible_to [ LimitRangeCommand, LimitInCommand ]

      with_keys [ "--day" ]
      with_help "Limit search for a certain day, multiple possible. Does not filter years or months"

      expects_nattrs (1..1)
      @attributes = []

      def search_in? path
        d = @attribute.first

        path.match(/[0-9]{4,4}\/[0-9]{2,2}\/#{d}\//)
      end

      protected

      # override
      def parse_attribute a
        # nothing
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
      include Uniqueness

      expects_nattrs (0..0)

      with_keys []
      with_help "Filter for certain Tag. Multiple possible."

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
      include Uniqueness

      expects_nattrs (0..0)

      with_keys ["--in-category", "-in-c"]
      with_help "Filter for certain Category. Multiple possible."

      def initialize(name)
        @catname = name
      end

      protected

      # override
      def filter(ary, meth)
        ary.map(&meth).flatten.select { |x| x.categories.include? @catname }
      end

    end


    class AddCommand < Command
      include InstanceAbleCommand
      include ExecuteableCommand
      include Uniqueness

      expects_nattrs (0..0)

      not_compatible_to [ Command ] # either add or something else.

      with_keys ["--add"]
      with_help "Add an entry. Default command."

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


    class ModifyCommand < Command
    end

    class EditCommand < ModifyCommand
      include InstanceAbleCommand
      include Uniqueness

      expects_nattrs (0..0)

      not_compatible_to [ LimitCommand, FilterCommand, ModifyCommand, AddCommand ]

      with_keys ["--edit"]
      with_help "Edit an entry"

    end

    class TagCommand < ModifyCommand
      include InstanceAbleCommand

      not_compatible_to [ EditCommand ]

      with_keys ["--tag"]
      with_help "Add a tag to one or more entries"

      expects_nattrs (0..0)

    end

    class CategorizeCommand < ModifyCommand
      include InstanceAbleCommand

      not_compatible_to [ EditCommand ]

      with_keys ["--category"]
      with_help "Add one or several entries to a category"

      expects_nattrs (0..0)

    end


    class Parser

      attr_reader :commands

      def initialize(argv, config)
        @argv = argv
        @config = config
        @commands = []
      end

      def parse!
        next_command! until @argv.empty?
      end

      def ensure_unique_commands!
        @commands.uniq! do |c|
          (c.is_a?(Uniqueness) ? c.uniqueness : false ) || c.class
        end
      end

      def available_commands
        [
          HelpCommand,
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
        ].select { |s| s.include? InstanceAbleCommand }
      end

      protected

      def debug(str)
        puts str if @config[:debug]
      end

      def next_command!
        cmd = @argv.shift
        debug "Shifted #{cmd} from #{@argv}"
        raise "Not a command: #{cmd}" if not Command.is_command? cmd

        debug "Searching for #{cmd}"
        commands = available_commands.select { |c| c.keys.include? cmd }

        if commands.length.zero?
          puts "Command not found: #{cmd}"
          exit 1
        end

        if commands.length > 1
          puts "Command seems to be not unique: #{cmd}"
          exit 1
        end

        debug "Creating instance for #{cmd}"
        @commands << create_instance!(commands.first)
      end

      def create_instance!(c)
        instance = c.new()

        0.upto(instance.class.expected_attr_count.max) do
          break if @argv.empty?

          if Command.is_command?(@argv.first)
            debug("Not adding #{@argv.first} as arg to #{instance}")
          else
            debug("Adding attribute to #{c} : #{@argv.first}")
            instance.add_attribute(@argv.shift)
          end
        end

        instance
      end

    end

  end

  module Iterateable

    def each &block
      raise NoMethodException.new("Not implemented")
    end

  end

  class TreeElement

    attr_reader :path, :index

    def self.from_path(path)
      raise NoMethodException.new("Not implemented")
    end

    def self.subs_from_path(path, gen_class, reader_commands, &block)
      Dir.new(path).entries.select(&block).map do |entry|
        next if ["..", "."].include? entry
        gen_class.from_path(path + "/" + entry, reader_commands)
      end
    end

    def self.index_from_path(path, regex)
      path.match(regex).to_s.to_i
    end

    def index_str(n = 2)
      @index.to_s.rjust(n, "0")
    end

  end


  class Entry < TreeElement

    attr_accessor :time
    attr_reader :content, :raw, :hash

    def initialize(time, path)
      @path = path
      @time = time
      content = File.read @path
      @content = content.encode(Encoding::UTF_8)
      @raw = content
    end

    def self.from_path(path)
      Entry.new(self.time_from_path(path), path)
    end

    def hash
      @hash ||= Digest::SHA512.hexdigest @raw
    end

    def to_sym
      @time.strftime("%H-%m-%S").to_sym
    end

    def to_hash
      h = Hash.new
      h[:time]    = @time.to_s
      h[:content] = @content
      h[:raw]     = @raw
      h[:hash]    = @hash
      h
    end

    protected

    def self.time_from_path(path)
      Time.parse path.match(/[0-2][0-9]-[0-9]{2,2}-[0-9]{2,2}/).to_s
    end

  end

  class Day < TreeElement
    include Iterateable

    attr_accessor :entries

    def initialize(entries, path, day_index = false)
      @path = path
      @index = day_index || Date.today.day
      @entries = entries
    end

    def to_sym
      @index.to_s.to_sym
    end

    def to_hash
      h = Hash.new
      h[:tags]        = []
      h[:categories]  = []
      h[:path]        = @path
      h[:entries]     = Hash.new
      @entries.compact.each { |e| h[:entries][e.to_sym] = e.to_hash }
      h
    end

    def each &block
      @entries.each(&block)
    end

    def self.from_path(path, reader_commands)
      index = self.index_from_path(path, /[0-9]{2,2}$/)
      entries = self.subs_from_path(path, Entry, reader_commands) do |subpath|
        File.file?(subpath) and reader_commands.lazy.map do |rcmd|
          rcmd.search_in? subpath
        end.any?
      end
      Day.new(entries, path, index)
    end

  end

  class Month < TreeElement
    include Iterateable

    attr_accessor :days

    def initialize(days, path, month_index = false)
      @path = path
      @index = month_index || Date.today.month
      @days = days
    end

    def each &block
      @days.each(&block)
    end

    def name
      Date::MONTHNAMES[@index].downcase
    end

    def to_sym
      @index.to_s.to_sym
    end

    def to_hash
      h = Hash.new
      h[:tags]        = []
      h[:categories]  = []
      h[:index]       = @index
      h[:path]        = @path
      h[:days]        = Hash.new
      @days.compact.each { |d| h[:days][d.to_sym] = d.to_hash }
      h
    end

    def self.from_path(path, reader_commands)
      index = self.index_from_path(path, /[0-9]{2,2}$/)
      days = self.subs_from_path(path, Day, reader_commands) do |subpath|
        File.directory?(subpath) and reader_commands.lazy.map do |rcmd|
          rcmd.search_in? subpath
        end.any?
      end
      Month.new(days, path, index)
    end

  end

  class Year < TreeElement
    include Iterateable

    attr_accessor :months

    def initialize(months, path, y = false)
      @year = y || Date.today.year
      @months = months
    end

    def each &block
      @months.each(&block)
    end

    def self.from_path(path, reader_commands)
      year = self.year_from_path path
      months = self.subs_from_path(path, Month, reader_commands) do |sub_path|
        File.directory? sub_path and reader_commands.lazy.map do |rcmd|
          rcmd.search_in? sub_path
        end.any?
      end

      Year.new(months, path, year)
    end

    def to_sym
      @year.to_s.to_sym
    end

    def to_hash
      h = Hash.new
      h[:tags]        = []
      h[:categories]  = []
      h[:path]        = @path
      h[:year]        = @year
      h[:months]      = Hash.new
      @months.compact.each { |month| h[:months][month.to_sym] = month.to_hash }
      h
    end

    protected

    def self.year_from_path path
      path.match(/[0-9]{4,4}$/).to_s.to_i
    end

  end

  class Tree < TreeElement
    include Iterateable

    @years = []

    def initialize(path, years)
      @path = path
      @years = years
    end

    def self.from_path(path, reader_commands)
      path = path
      years = self.subs_from_path(path, Year, reader_commands) do |subpath|
        File.directory?(subpath) and reader_commands.lazy.map do |rcmd|
          rcmd.search_in? sub_path
        end.any?
      end
      Tree.new(path, years)
    end

    def to_sym
      @path.to_s.to_sym
    end

    def to_hash
      h = Hash.new
      h[:tags]        = []
      h[:categories]  = []
      h[:path]        = @path
      h[:years]       = Hash.new
      @years.compact.each { |year| h[:years][year.to_sym] = year.to_hash }
      h
    end

    def each(&block)
      @years.each(&block)
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

  class Executer

    def initialize(commands, config)
      @config = config
      @commands = commands
      raise "Invalid command state..." if not valid?
    end

    def execute!
      try_precommands and exit 0

      tree = build_tree
      puts ::JSON.pretty_generate tree.to_hash
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
      queries << ListCommand.new if queries.empty?
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
  puts "Available: #{cp.available_commands.map(&:keys).flatten}"
  cp.parse!

  puts cp.commands
  puts cp.commands.map(&:inspect)

  puts "---"

  ex = Diary::Executer.new(cp.commands, config)
  ex.execute!
end
