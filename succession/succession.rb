DEBUG = false

require 'pp'
require 'rgl/adjacency'
require 'rgl/bidirectional'
require 'rgl/dot'
require 'rgl/traversal'
require 'rgl/connected_components'
require 'rgl/topsort'
include RGL

class Succession
  attr_accessor :founder
  attr_accessor :graph
  
  def initialize
    @graph=DirectedAdjacencyGraph.new
    @claimants = Array.new
    @is_calculated = false
  end
  
  def add_claimant(claimant)
    @claimants << claimant
  end

  def add_relationship(child, parent1, parent2)
    @graph.add_edge(parent1, child)
    @graph.add_edge(parent2, child)
  end

  def heir
    calculate_relatedness! unless @is_calculated
    calculated_claimants = @graph.vertices.keep_if {|pers| @claimants.include? pers}
    the_heir = Person.new("no heir found", 0.0)
    calculated_claimants.each {|pers|
      the_heir = pers if pers.relatedness > the_heir.relatedness
    }
    the_heir
  end

  def output_graph
    @graph.write_to_graphic_file('jpg')
  end

  private
  def calculate_relatedness!
    puts "Calculating relatedness:" if DEBUG
    bfs  = @graph.bfs_iterator(@founder)
    bfs.set_examine_edge_event_handler{ |from, to|
      to.relatedness += (from.relatedness / 2)
      puts "edge from: [#{from}] to: [#{to}] = #{to.relatedness.to_s}" if DEBUG
    }
    bfs.set_to_end  # does the search
    @is_calculated = true
  end
end

class Person
  include Comparable
  attr_accessor :name
  attr_accessor :relatedness
  
  def initialize(name, relatedness)
    @name = name
    @relatedness = relatedness
  end

  def equal?(other)
    return other.name == @name
  end

  def eql?(other)
    return other.name == @name
  end

  def hash
    return name.hash
  end

  def ==(other)
    return self.name == other.name
  end

  def <=>(other_person)
    self.name <=> other_person.name
  end

  def to_s
    @name
  end
end



class Parser
  attr_accessor :succession
  
  def initialize
    @succession = Succession.new()
    @phase = "parse_bounds"
    @relationships_parsed = 0
    @claimants_parsed = 0
  end

  def parse_input(line)
    send(@phase, line)
  end

  def parse_bounds(line)
    @relationships_size = line.split[0].to_i
    @claimants_size = line.split[1].to_i
    @phase = "parse_founder"
  end

  def parse_founder(line)
    founder = Person.new(line.strip, 1.0)
    @succession.founder = founder
    puts "founder: #{@succession.founder}" if DEBUG
    @phase = "parse_relationship"
  end

  def parse_relationship(line)
    @relationships_parsed += 1
    relationship = line.split
    child = Person.new(relationship[0], 0.0)
    parent_a = Person.new(relationship[1], 0.0)
    parent_b = Person.new(relationship[2], 0.0)
    @succession.add_relationship child, parent_a, parent_b
    puts "relationship: #{relationship}" if DEBUG
    if @relationships_parsed == @relationships_size
      @phase = "parse_claimant"
      @succession.output_graph
    end
  end

  def parse_claimant(line)
    puts "claimant: #{line}" if DEBUG
    claimant = Person.new(line.strip, 0.0)
    @succession.add_claimant claimant
  end
end


parser = Parser.new
ARGF.each do |line|
    parser.parse_input line
end

puts parser.succession.heir.to_s

