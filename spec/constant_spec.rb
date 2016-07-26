require 'spec_helper'

describe 'Constants' do
  let(:graph) { Tensorflow::Graph.new }

  let(:session) { Tensorflow::Session.new }
  let(:result) { session.run(nil, ["output"], nil) }
  before {
    define_op
    graph.graph_def_raw = Tensorflow::GraphDef.encode(graph.graph_def)
    session.extend_graph(graph)
  }

  subject { result[0] }

  context 'add' do
    let(:input1) { graph.constant( "const1",[Complex(2,2), Complex(2,34)], :complex) }
    let(:input2) { graph.constant( "const2",[Complex(2,2), Complex(-32,22)], :complex) }
    let(:define_op) { graph.define_op("Add",'output', [input1, input2],"",nil) }

    it { is_expected.to all_be_close([Complex(4.0,4.0), Complex(-30.0,56.0)]) }
  end

  context 'sub' do
    # If we could use the same inputs for all tests, it would be even more DRY
    let(:input1) { graph.constant( "const1",[634,432], :float64) }
    let(:input2) { graph.constant( "const2",[332,332], :float64) }
    let(:define_op) { graph.define_op("Sub",'output', [input1, input2],"",nil) }

    it { is_expected.to all_be_close([302.0,100.0]) }
  end
end