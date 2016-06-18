require_relative 'tensorflow'

class GraphNode
  attr_accessor :node_def
end

class Graph
  attr_accessor :availableOps, :constants, :variables, :graph_def
  def initialize()
  	self.availableOps = loadAvailableOps()
  end

  def loadAvailableOps()
  	ops_reader = File.read('ops.pb')
    op_list = Tensorflow::OpList.decode(ops_reader)
    availableOps = Hash.new
    (0..op_list.op.length - 1).each do |i|
      availableOps[op_list.op[i].name.downcase!] = op_list.op[i]
    end
    availableOps
  end

  def graph_def_from_reader(filename)
  	reader = File.read(filename)
  	self.graph_def = Tensorflow::GraphDef.decode(reader)
  end
end

def placeholder()


end
a = Graph.new()
puts a.availableOps["addn"].input_arg[0]
puts a.availableOps["addn"]

availableOps = Hash.new
availableOps["rwewer"] = Tensorflow::AttrValue.new
b = Tensorflow::NodeDef.new(:name => "wqeq",:op=>"rd", :attr => availableOps)