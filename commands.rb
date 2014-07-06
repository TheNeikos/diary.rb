module Diary
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
        tree.years.each do |year|
          year.months.each do |month|
            month.days.each do |day|
              day.entries.each do |entry|
                puts "[#{entry.abbrev_hash}] #{entry.time}"
              end
            end
          end
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
end

