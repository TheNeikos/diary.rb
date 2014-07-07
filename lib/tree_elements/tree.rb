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
