# frozen_string_literal: true

module WebConsole
  # A session lets you persist an +Evaluator+ instance in memory associated
  # with multiple bindings.
  #
  # Each newly created session is persisted into memory and you can find it
  # later by its +id+.
  #
  # A session may be associated with multiple bindings. This is used by the
  # error pages only, as currently, this is the only client that needs to do
  # that.
  class Session
    cattr_reader :inmemory_storage
    @@inmemory_storage = {}

    class << self
      # Finds a persisted session in memory by its id.
      #
      # Returns a persisted session if found in memory.
      # Raises NotFound error unless found in memory.
      def find(id)
        inmemory_storage[id]
      end

      # Create a Session from an binding or exception in a storage.
      #
      # The storage is expected to respond to #[]. The binding is expected in
      # :__web_console_binding and the exception in :__web_console_exception.
      #
      # Can return nil, if no binding or exception have been preserved in the
      # storage.
      def from(storage)
        if exc = storage[:__web_console_exception]
          new(ExceptionMapper.new(exc))
        elsif binding = storage[:__web_console_binding]
          new([binding])
        end
      end
    end

    # An unique identifier for every REPL.
    attr_reader :id

    def initialize(bindings)
      @id = SecureRandom.hex(16)
      @bindings = bindings
      @evaluator = Evaluator.new(@current_binding = bindings.first)

      store_into_memory
    end

    # Evaluate +input+ on the current Evaluator associated binding.
    #
    # Returns a string of the Evaluator output.
    def eval(input)
      result = @evaluator.eval(input)
      save_result(input, result, $user_id) if Rails.application.config.webconsole_db_storage.present?
      result
    end

    def save_result(input, result, user_id)
      model =  Rails.application.config.webconsole_db_storage[:model].constantize
      input_column = Rails.application.config.webconsole_db_storage[:columns][:input]
      result_column = Rails.application.config.webconsole_db_storage[:columns][:result]
      user_id_column = Rails.application.config.webconsole_db_storage[:columns][:user_id]
      model.create({input_column => input, result_column => result, user_id_column => user_id})
    end

    # Switches the current binding to the one at specified +index+.
    #
    # Returns nothing.
    def switch_binding_to(index)
      @evaluator = Evaluator.new(@current_binding = @bindings[index.to_i])
    end

    # Returns context of the current binding
    def context(objpath)
      Context.new(@current_binding).extract(objpath)
    end

    private

      def store_into_memory
        inmemory_storage[id] = self
      end
  end
end
