module MailyHerald
  class Context
    class Drop < Liquid::Drop
      def initialize attrs
        @attrs = attrs
      end

      def has_key?(name)
        name = name.to_s

        @attrs.has_key? name
      end

      def invoke_drop name
        name = name.to_s

        if @attrs.has_key? name
          if @attrs[name].is_a? Hash
            Drop.new(@attrs[name])
          else
            @attrs[name].call
          end
        else
          nil
        end
      end

      alias :[] :invoke_drop
    end

    class Attributes
      def initialize block
        @attrs = {}
        @node = @parent_node = @attrs
        @block = block
      end

      def setup entity = nil, subscription = nil
        if entity && subscription
          @attrs["subscription"] = Proc.new{ subscription }
          instance_exec entity, &@block
        else
          instance_eval &@block
        end
      end

      def attribute_group name, &block
        @parent_node = @node
        @parent_node[name.to_s] ||= {}
        @node = @parent_node[name.to_s]
        yield
        @node = @parent_node
      end

      def attribute name, &block
        @node[name.to_s] = block
      end

      def for_drop
        @attrs
      end

      def method_missing(m, *args, &block)
        true
      end
    end

    attr_accessor :entity
    attr_reader :name

    def initialize name
      @name = name
    end

    def model
      @model ||= @scope.call.table.engine
    end

    def scope &block
      if block_given?
        @scope = block
      else
        @scope.call
      end
    end

    def destination &block
      if block_given?
        @destination = block
      else
        @destination
      end
    end

    def attributes &block
      if block_given?
        @attributes = Attributes.new block
      else
        @attributes
      end
    end

    def attributes_list
      attributes = @attributes.dup
      attributes.setup 
      attributes.for_drop
    end

    def drop_for entity, subscription
      attributes = @attributes.dup
      attributes.setup entity, subscription
      Drop.new(attributes.for_drop)
    end

  end
end
