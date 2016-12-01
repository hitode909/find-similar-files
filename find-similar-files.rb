Bundler.require

class Pair
  attr_reader :path1, :path2

  def initialize path1, path2
    @path1 = path1
    @path2 = path2
  end

  def pair
    [path1, path2]
  end

  def similarity
    return @similarity if @similarity
    content1 = open_and_normalize(path1)
    content2 = open_and_normalize(path2)
    return 0.0 if size_is_too_differ content1, content2
    @similarity = String::Similarity.levenshtein content1, content2
    warn [@similarity, path1, path2].inspect
    @similarity
  end

  def size_is_too_differ content1, content2
    # heuristic!!!
    (content1.length - content2.length).abs > 50
  end

  def diff
     Diffy::Diff.new(open_and_normalize(path1), open_and_normalize(path2), context: 0)
  end

  def open_and_normalize path
    open(path).read.gsub(/^\s+/, '').gsub(/[ \t]+/, ' ')
  end
end

class SimilarFilesFinder
  def initialize
    @files={}
  end

  def look_files files
    pairs = files.combination(2).map{|path1, path2|
      look path1, path2
    }.compact
    Parallel.each_with_index(pairs, in_threads: Parallel.processor_count) {|pair, index|
      warn ['preparing similarity', index, pairs.length, pair.similarity].inspect
    }
    pairs.sort_by{|pair| -pair.similarity }
  end

  def look path1, path2
    return unless File.file?(path1)
    return unless File.file?(path2)
    Pair.new(path1, path2)
  end

  def summary
    @files.each_pair.select{|k, v|
      v.length > 1
    }.map{|k, v| v}
  end
end

finder = SimilarFilesFinder.new
pairs = finder.look_files ARGV
pairs[0..50].each{|pair|
#.select{ |pair|
#  pair.similarity > 0.95 # heuristic!!!
#}
  if ENV['OUTPUT_DIFF']
    diff = pair.diff
    next if diff.to_s.split(/\n/).length > 40
    puts ['###', pair.similarity, pair.pair].flatten.join(" ")
    puts
    diff = pair.diff
    if pair.similarity < 1.0
      puts '```diff'
      puts diff
      puts "```\n"
    end
  else
    puts [pair.similarity, pair.pair].flatten.join("\t")
  end
}
exit 0
