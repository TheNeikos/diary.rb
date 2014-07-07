class Array

  def includes_any? other
    other.lazy.map { |o| self.include? o }.any?
  end

end
