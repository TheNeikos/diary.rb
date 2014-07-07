module Diary
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
end

