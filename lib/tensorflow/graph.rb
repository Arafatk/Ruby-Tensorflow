# A TensorFlow computation, represented as a dataflow graph.
# A Graph contains a set of Operation objects, which represent units of computation; and Tensor objects, which represent the units of data that flow between operations.
# Official documentation of {graph}[https://www.tensorflow.org/versions/r0.9/api_docs/python/framework.html#Graph].
# Graph represents a computation graph. Graphs may be shared between sessions.
class Tensorflow::Graph
  attr_accessor :c
  # @!attribute c
  #  contains the graph representation.
  def initialize
    self.c = Tensorflow::TF_NewGraph()
  end

  def delete_graph
    Tensorflow::TF_DeleteGraph(self.c)
  end

  # write_to writes out a serialized representation of graph in binary wire format.
  # This graph defination can be written to file using write_file function and then
  # converted to a readable form using converter.py file in the gem.
  def write_to
    buffer = Tensorflow::TF_NewBuffer()
    status = Tensorflow::Status.new
    Tensorflow::TF_GraphToGraphDef(self.c, buffer, status.c)
    Tensorflow::buffer_write(buffer)
  end

  # writeto writes out a serialized representation of graph to a file.
  def write_file(filename)
    File.open(filename, 'w') { |file| file.write(write_to) }
  end

  # Loads a graph stored in pb file into a graph def. This way you can define the graph
  # in python / ruby, save it in pb file and load it in ruby. The limitation of
  # is that it can only read binary wire format for protocol buffer messages
  # In order to debug convoluted messages in ruby its always a good idea to convert the format
  # to a readable form using converter.py file in the gem and specifying the file name of
  # the .pb file to be converted. This makes use of import function.
  def read_file(filename)
    raise ArgumentError, "File does not exist" if !File.file?(filename)
    reader = File.read(filename)
    import(reader,"")
  end

  # import function imports the nodes and edges from
  # a serialized representation of another Graph into g.
  # Names of imported nodes will be prefixed with prefix.
  def import(byte, prefix)
    cprefix = CString(prefix)
    opts = Tensorflow::TF_NewImportGraphDefOptions()
    Tensorflow::TF_ImportGraphDefOptionsSetPrefix(opts, cprefix)

    buffer = Tensorflow::TF_NewBuffer()
    Tensorflow::buffer_read(buffer, CString(byte))
    status = Tensorflow::Status.new
    Tensorflow::TF_GraphImportGraphDef(self.c, buffer, opts, status.c)
  end

  # Operation returns the Operation named name in the Graph, or nil if no such
  # operation is present.
  def operation(name)
    c_operation = Tensorflow::TF_GraphOperationByName(self.c, CString(name))
    operation = Tensorflow::Operation.new
    return nil if c_operation == nil
    operation.c = c_operation
    operation.g = self
    return operation
  end

  # Adds a placeholder to the Graph, a placeholder is an
  # operation that must be fed with data on execution.
  # Notice that this does not have the shape parameter.
  def placeholder(name, type_enum)
    opspec = Tensorflow::OpSpec.new
    opspec.name = name
    opspec.type = "Placeholder"
    opspec.attr["dtype"] = type_enum
    operation = AddOperation(opspec)
    return operation.output(0)
  end

  # Creates a constant Tensor that is added to the graph with a specified name.
  # Official documentation of {tf.constant}[https://www.tensorflow.org/versions/r0.9/api_docs/python/constant_op.html#constant].
  def const(name, value)
    # Value is the tensor but for now we can ignore that shit
    # Raise error if name and data type are incorrect in any way
    # we have both datatype and tensor for this.
    opspec = Tensorflow::OpSpec.new
    opspec.type = "Const"
    opspec.name = name
    opspec.attr["dtype"] = value.type_num
    opspec.attr["value"] = value
    operation = AddOperation(opspec)
    return operation.output(0)
  end

  # Add a method for variables so that they are not alone
  # everything uptil set attributes is okay but then we need reflect equivalent for ruby
  def AddOperation(opspec)
    opspec.name = opspec.type if opspec.name == nil
    cname = CString(opspec.name)
    ctype = CString(opspec.type)
    cdesc = Tensorflow::TF_NewOperation(self.c, ctype, cname)

    if opspec.input.length > 0
      opspec.input.each do |name|
        Tensorflow::TF_AddInput(cdesc, name.c)
      end
      # Add the case of inputlist
    end

    status = Tensorflow::Status.new
    opspec.attr.each do |name, value|
      cdesc, status = setattr(cdesc, status, name, value)
  			# Memory leak here as the TF_OperationDescription
  			# object will not be cleaned up. At the time of this
  			# writing, this was next to impossible since it
  			# required value to be a string tensor with
  			# incorrectly encoded strings. Given this rarity, live
  			# with the memory leak.  If it becomes a real problem,
  			# consider adding a TF_DeleteOperationDescription
  			# function to the C API.
    end

    operation = Tensorflow::Operation.new
    operation.c = Tensorflow::TF_FinishOperation(cdesc, status.c)
    operation.g = self
    return operation
  end

  # How are we using a way to set attributes for string and other types.
  def setattr(cdesc, status, name, value) # adding extra type for fun
    cAttrName = CString(name)
    type = "DataType"     if name == "dtype"
    type = "Tensor"       if name == "value"

    if type == "string"
      c_array[0] = value
      cstr = c_array[0]
      Tensorflow::TF_SetAttrString(cdesc, cAttrName, cstr, value.length)
    elsif type == "stringlen"
      size = value.length
      c_array = Tensorflow::String_Vector.new
      list = Tensorflow::Long_long.new
    elsif type == "DataType"
      Tensorflow::TF_SetAttrType(cdesc, cAttrName, value)
    elsif type == "Tensor"
      Tensorflow::TF_SetAttrTensor(cdesc, cAttrName, value.tensor, status.c)
    # Tensor list is also present
    else
      puts "This is not working out."
    end
    return cdesc, status
  end
end
