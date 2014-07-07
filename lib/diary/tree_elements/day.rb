module Diary
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
end
