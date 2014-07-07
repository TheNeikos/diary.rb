module Diary
  class TreeElement

    attr_reader :path, :index

    def self.from_path(path)
      raise NoMethodException.new("Not implemented")
    end

    def self.subs_from_path(path, gen_class, reader_commands, &block)
      Dir.new(path).entries.select(&block).map do |entry|
        next if ["..", "."].include? entry
        gen_class.from_path(path + "/" + entry, reader_commands)
      end.compact
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
    attr_reader :content, :raw, :hash, :tags, :categories

    def initialize(time, path)
      @path = path
      @time = time
      content = File.read @path
      @content = content.encode(Encoding::UTF_8)
      @raw = content
    end

    def self.from_path(path, reader_commands)
      if reader_commands.lazy.map { |rcmd| rcmd.search_in? path }.any_or_none?
        Entry.new(self.time_from_path(path), path)
      end
    end

    def metadata
      {
        :path       => @path,
        :time       => @time,
        :tags       => @tags,
        :categories => @categories,
      }
    end

    def hash
      @hash ||= Digest::SHA512.hexdigest(@raw + metadata.to_s)
    end

    def abbrev_hash
      hash[0,7]
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
      r = /[0-9]{4,4}\/[0-9]{2,2}\/[0-9]{2,2}\/[0-2][0-9]-[0-9]{2,2}-[0-9]{2,2}/
      pathpart = path.match(r).to_s
      Time.strptime pathpart, "%Y/%m/%d/%H-%M-%S"
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
        File.file?(path + "/" + subpath) and reader_commands.lazy.map do |rcmd|
          rcmd.search_in? subpath
        end.any_or_none?
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
        File.directory?(path + "/" + subpath) and reader_commands.lazy.map do |rcmd|
          rcmd.search_in? subpath
        end.any_or_none?
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
      months = self.subs_from_path(path, Month, reader_commands) do |subpath|
        File.directory?(path + "/" + subpath) and reader_commands.lazy.map do |rcmd|
          rcmd.search_in? sub_path
        end.any_or_none?
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

    attr_reader :years

    @years = []

    def initialize(path, years)
      @path = path
      @years = years
    end

    def self.from_path(path, reader_commands)
      path = path
      years = self.subs_from_path(path, Year, reader_commands) do |subpath|
        File.directory?(path + "/" + subpath) and reader_commands.lazy.map do |rcmd|
          rcmd.search_in? sub_path
        end.any_or_none?
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
end

