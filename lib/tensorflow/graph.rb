# A TensorFlow computation is represented as a dataflow graph.
# A Graph contains a set of Operation objects, which represent units of computation; and Tensor objects, which represent the units of data that flow between operations.
# Official documentation of {graph}[https://www.tensorflow.org/api_docs/python/framework/core_graph_data_structures#Graph].
# Graph represents a computation graph. Graphs may be shared between sessions.
class Tensorflow::Graph
    attr_accessor :c
    # @!attribute c
    #  contains the graph representation.
    def initialize
        self.c = TensorflowAPI::new_graph()
        @number_of_defaults_created = Hash.new(0)
    end

    def delete_graph
        Tensorflow::delete_graph(c)
    end

    # write_to writes out a serialized representation of graph in binary wire format.
    # This graph defination can be written to file using write_file function and then
    # converted to a readable form using converter.py file in the gem.
    def write_to
        buffer = Tensorflow::TF_NewBuffer()
        status = Tensorflow::Status.new
        Tensorflow::TF_GraphToGraphDef(c, buffer, status.c)
        Tensorflow.buffer_write(buffer)
    end

    # write_file writes out a serialized representation of graph to a file.
    def write_file(filename)
        File.open(filename, 'w') { |file| file.write(write_to) }
    end

    # import function imports the nodes and edges from
    # a serialized representation of another Graph into g.
    # Names of imported nodes will be prefixed with prefix.
    def import(byte, prefix)
        cprefix = CString(prefix)
        opts = Tensorflow::TF_NewImportGraphDefOptions()
        Tensorflow::TF_ImportGraphDefOptionsSetPrefix(opts, cprefix)

        buffer = Tensorflow::TF_NewBuffer()
        Tensorflow.buffer_read(buffer, CString(byte))
        status = Tensorflow::Status.new
        Tensorflow::TF_GraphImportGraphDef(self.c, buffer, opts, status.c)
    end

    # Loads a graph stored in pb file into a graph def. This way you can define the graph
    # in python / ruby, save it in pb file and load it in ruby. The limitation of
    # is that it can only read binary wire format for protocol buffer messages
    # In order to debug convoluted messages in ruby its always a good idea to convert the format
    # to a readable form using converter.py file in the gem and specifying the file name of
    # the .pb file to be converted. This makes use of import function.
    def read_file(filename)
        raise ArgumentError, 'File does not exist' unless File.file?(filename)
        reader = File.read(filename)
        import(reader, '')
    end

    # Operation returns the Operation named name in the Graph, or nil if no such
    # operation is present.
    def operation(name)
        c_operation = Tensorflow::TF_GraphOperationByName(c, CString(name))
        warn("No Operation with the name #{name} exists.") if c_operation.nil?
        Tensorflow::Operation.new(c_operation, self)
    end

    # Adds a placeholder to the Graph, a placeholder is an
    # operation that must be fed with data on execution.
    # Notice that this does not have the shape parameter.
    # Official documentation of {tf.placeholder}[https://www.tensorflow.org/api_docs/python/io_ops/placeholders#placeholder].
    def placeholder(name, type_enum)
        opspec = Tensorflow::OpSpec.new(name, 'Placeholder', 'dtype' => {type_enum => 'DataType'})
        operation = AddOperation(opspec)
        operation.output(0)
    end

    # Creates a constant Tensor that is added to the graph with a specified name.
    # Official documentation of {tf.constant}[https://www.tensorflow.org/versions/r0.9/api_docs/python/constant_op.html#constant].
    def constant(value, name: nil, dtype: nil)
        # Value is the tensor but for now we can ignore that shit
        # Raise error if name and data type are incorrect in any way
        # we have both datatype and tensor for this.
        tensor = Tensorflow::Tensor.new(value, dtype)
        name ||= default_name('Constant')
        opspec = Tensorflow::OpSpec.new(name, 'Const', 'dtype' => {tensor.type_num => 'DataType' }, 'value' => {tensor => 'tensor'})
        operation = AddOperation(opspec)
        operation.output(0)
    end

    # Add a method for variables so that they are not alone
    # everything uptil set attributes is okay but then we need reflect equivalent for ruby
    def AddOperation(opspec)
        opspec.name = opspec.type if opspec.name.nil?
        opspec.name = opspec.type if opspec.name == ''
        cname = CString(opspec.name)
        ctype = CString(opspec.type)
        cdesc = TensorflowAPI::new_operation(c, ctype, cname)

        unless opspec.input.empty?
            opspec.input.each do |name|
                Tensorflow::add_input(cdesc, name.c)
            end
        end

        unless opspec.inputlist.empty?
            c_array = Tensorflow::TF_Output_vector.new
            length = opspec.inputlist.length
            opspec.inputlist.each_with_index { |value, i| c_array[i] = value.c }
            c_array = Tensorflow::TF_Output_array_from_vector(c_array)
            cdesc = Tensorflow.input_list_helper(cdesc, c_array, length)
         end

        status = TensorflowAPI::Status.new
        opspec.attr.each do |name, value|
            cdesc, status = set_attributes(cdesc, status, name, value)
            # Memory leak here as the TF_OperationDescription
            # object will not be cleaned up. At the time of this
            # writing, this was next to impossible since it
            # required value to be a string tensor with
            # incorrectly encoded strings. Given this rarity, live
            # with the memory leak.  If it becomes a real problem,
            # consider adding a TF_DeleteOperationDescription
            # function to the C API.
        end
        Tensorflow::Operation.new(Tensorflow::finish_operation(cdesc, status.c), self)
    end

private
    # Setting attributes is a complicated process for ruby and could have been much
    # more convinient and automated if ruby had run-time reflection like golang.
    # Basically its not possible to differentiate between int32 and int64
    # or float32 and double(float64). This is why attribute specification has been done in the following way.
    # Make a hash of Attributes
    # With the key as the name of the attribute and the value as a hash of one object.
    # The first index of the array is the value itself and the second is the type of the attributes.
    # You can find the types of the attributes on this link https://github.com/tensorflow/tensorflow/blob/master/tensorflow/core/ops/ops.pbtxt
    # This API is Currently being improved feel free to raise an issue or ask clarification about any query regarding this.
    #
    def set_attributes(cdesc, status, name, value)
        cAttrName = CString(name)
        if value.is_a?(Hash)
           value, type = value.first
        end
        # Some defaults types for attributes of given name
        type = 'DataType'      if name == 'dtype'
        type = 'Tensor'        if name == 'value'
        type = 'int64'         if name == 'channels'
        type = 'DataType'      if name == 'DstT'
        type = 'int32_array'   if name == 'size/Const'

        if value.is_a?(Hash)
          value, type = value.first
        end
        case type
        when 'string'
            Tensorflow::TF_SetAttrString(cdesc, cAttrName, CString(value), value.length)
        when 'string_array'
            size = value.length
            c_string_vector = Tensorflow::String_Vector.new
            list = Tensorflow::Long_long.new
            value.each_with_index do |string, index|
                c_string_vector[index] = string
                list[index] = string.length
            end
            c_array = string_array_from_string_vector(c_string_vector)
            Tensorflow::TF_SetAttrString(cdesc, cAttrName, c_array, list, value.length)
        when 'int32'
            Tensorflow::TF_SetAttrInt(cdesc, cAttrName, value)
        when 'int32_array'
            size = value.length
            list = Tensorflow::Int.new
            value.each_with_index do |number, index|
                c_string_vector[index] = number
            end
            Tensorflow::TF_SetAttrIntList(cdesc, cAttrName, list, size)
        when 'int64'
            Tensorflow::TF_SetAttrInt(cdesc, cAttrName, value)
        when 'int64_array'
            size = value.length
            list = Tensorflow::Long_long.new
            value.each_with_index do |number, index|
                c_string_vector[index] = number
            end
            Tensorflow::TF_SetAttrIntList(cdesc, cAttrName, list, size)
        when 'float32'
            Tensorflow::TF_SetAttrFloat(cdesc, cAttrName, value)
        when 'float32_array'
            size = value.length
            list = Tensorflow::Float.new
            value.each_with_index do |number, index|
                c_string_vector[index] = number
            end
            Tensorflow::TF_SetAttrFloatList(cdesc, cAttrName, list, size)
        when 'DataType'
            TensorflowAPI::set_attr_type(cdesc, cAttrName, value)
        when 'Tensor'
            TensorflowAPI::set_attr_tensor(cdesc, cAttrName, value.tensor, status)
        # TODO: Insert Tensor_list, DataType_list, Bool
        else
            raise 'Attribute type not supported or attribute type not specififed properly. Please look into the documentation for set_attributes in the graph class for more information.'
        end
        # Shapes can be done, but will require that it be
        # distinguishable from []int64. Which is fine, it
        # probably makes sense to define a Shape type anyway,
        # since that should handle partially known shapes as
        # well and hide the special meaning of -1?
        [cdesc, status]
    end

    # Returns a default name for a new variable or constant.
    # The name increments for each one created: Variable:0, Variable:1, and so on.
    def default_name(type)
        name = "#{type}_#{@number_of_defaults_created[type]}"
        @number_of_defaults_created[type] += 1
        name
    end
end
