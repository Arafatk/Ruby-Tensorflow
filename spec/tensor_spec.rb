require 'spec_helper'

describe "Tensor" do 
	it "Should Give correct results." do 
	  err = 1e-4
      input1 = Tensor.new([[1,2],[3,4]])
      input2 = Tensor.new([[7,3],[4,21]])
      graph = Graph.new()
      graph.graph_from_reader(File.dirname(__FILE__)+'/example_graphs/example_int64.pb') 
      session = Session.new()
      session.extend_graph(graph)
      inputs = Hash.new
 	  inputs['input1'] = input1.tensor
	  inputs['input2'] = input2.tensor
	  session.run(inputs, ['output'], [])
	  expect(1).to be_within(err).of(1)
	end
end