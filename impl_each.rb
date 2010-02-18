
module ImplEach
  def each(&f_proc)
    @eachees.each { |eachee| f_proc.call(eachee) }
  end
end

