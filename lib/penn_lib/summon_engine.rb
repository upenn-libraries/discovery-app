
class PennLib::SummonEngine < BentoSearch::SummonEngine

  def search_implementation(args)
    results = super(args)
    results.each do |item|
      item.link = 'https://proxy.library.upenn.edu/login?url=' + item.link
    end
    return results
  end
end
