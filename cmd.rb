#!/usr/bin/ruby
require "./lib/net"

def main
  path = "."
  if ARGV.length > 0 then
    path = ARGV[0]
  end
  unless File.directory? path
    puts "invalid directory: #{path}"
    exit 1
  end
  net = Net.new path
  graph_path = net.create
  puts "graph generated @ #{graph_path}"
end

main
