module Diary
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
end
