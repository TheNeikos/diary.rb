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

end


