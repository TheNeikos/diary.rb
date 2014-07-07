class Enumerator::Lazy

  def any_or_none?
    self.entries.empty? or self.entries.any?
  end

end
