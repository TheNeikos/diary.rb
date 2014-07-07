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
