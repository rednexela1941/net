#!/usr/bin/ruby
require "rake_text"
require "thread"
require "graphviz"

class RakeText
  alias analyze analyse
end

class FileLine
  def initialize(path, line, line_num, keywords)
    @path = path
    @line = line
    @line_num = line_num
    @keywords = keywords
    @node = nil
  end

  attr_accessor :path, :line, :line_num, :keywords, :node

  def output
    puts "#{path}::#{line_num} #{line}"
  end

  alias to_s output
end

class Graph
  def initialize
    @pairs = Hash.new
  end

  def add_pair(a, b)
    if a == b then return end
    min = if a < b then a else b end
    max = if a < b then b else a end
    @pairs[min] = Hash.new unless @pairs.has_key? min
    if @pairs[min].has_key? max
      @pairs[min][max] += 1
    else
      @pairs[min][max] = 1
    end
  end

  def to_s
    out = String.new
    @pairs.each do |k, v|
      out += "#{k}: #{v}\n"
    end
    out
  end

  def generate
    viz = Graphviz::Graph.new "net"
    nodes = Hash.new
    @pairs.each do |k, hash|
      nodes[k] = viz.add_node k unless nodes.has_key? k
      hash.each do |sk, count|
        nodes[sk] = viz.add_node sk unless nodes.has_key? sk
        nodes[k].connect nodes[sk]
      end
    end
    viz
  end
end

class Net
  def initialize(dir)
    @root_dir = dir
    @rake = RakeText.new
    @graph = Graph.new
  end

  attr_reader :root_dir

  def create
    out = parse
    net = generate_net out
    keys = net.keys.sort do |a, b|
      net[b].length - net[a].length
    end
    output_lines = Array.new
    keys.each do |k|
      output_lines.push "* #{k}"
      net[k].each do |line|
        text = line.line
        index = text.index k
        index = 0 if index == nil
        left = index - 15
        left = 0 if left < 0
        right = left + 30
        summary = line.line[left..right].gsub(/^[\s]+/, "").gsub(/[\s]+$/, "")
        summary.gsub!(/[\s]+/, " ")
        output_lines.push "** [[file:#{line.path}::#{line.line_num}][#{summary}]]"
        line.keywords.each do |kw|
          @graph.add_pair k, kw
        end
      end
    end
    write output_lines
    # puts "#@graph"
    graph = @graph.generate
    graph_path = File.join @root_dir, "graph.pdf"
    Graphviz::output(graph, :path => graph_path)
    graph_path
  end

  def walk_path(path)
    files = Array.new
    Dir.children(path).each do |child|
      fp = File.join path, child
      if File.file?(fp) and not fp.match?(/net.org$/) and fp.match?(/(org|txt)$/)
        files.push fp
      elsif File.directory?(fp)
        files.concat walk_path(fp)
      end
    end
    files
  end

  def write(lines)
    output_path = File.join(@root_dir, "net.org")
    File.open(output_path, "w") do |f|
      lines.each do |line|
        f.write line
        f.write "\n"
      end
    end
  end

  def parse
    queue = Queue.new
    out = Queue.new
    walk_path(@root_dir).each do |fp|
      queue.push fp
    end
    threads = Array.new
    5.times do
      threads.push start_worker(queue, out)
    end
    threads.each do |t|
      t.join
    end
    out
  end

  def generate_net(out)
    kw = Hash.new
    until out.empty?
      line = out.pop
      line.keywords.map(&:downcase).each do |key|
        kw[key] = Array.new unless kw.has_key?(key.downcase)
        kw[key].push line
      end
    end
    kw
  end

  def start_worker(queue, out)
    Thread.new do
      until queue.empty?
        path = queue.pop
        line_num = 1
        File.foreach(path) do |line|
          line.gsub!(/\*+/, "")
          keys = @rake.analyze line, RakeText.SMART
          words = []
          keys.each do |k|
            words.push k[0] if k[0].match?(/[\w]+/)
          end
          out.push FileLine.new(path, line, line_num, words) unless keys.empty?
          line_num += 1
        end
      end
    end
  end
end
