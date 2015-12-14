require 'tempfile'

module EXEL
  class Context
    attr_reader :table

    def initialize(initial_context = {})
      @table = initial_context
    end

    def serialize
      remotized_table = @table.each_with_object({}) { |(key, value), acc| acc[key] = EXEL::Value.remotize(value) }
      EXEL::Value.remotize(serialized_context(remotized_table))
    end

    def self.deserialize(uri)
      file = EXEL::Value.localize(uri)
      context = Marshal.load(file.read)
      file.close
      context
    end

    def [](key)
      value = EXEL::Value.localize(@table[key])
      value = get_deferred(value)
      @table[key] = value
      value
    end

    def []=(key, value)
      @table[key] = value
    end

    def merge!(hash)
      @table.merge!(hash)
      self
    end

    def delete(key)
      @table.delete(key)
    end

    def ==(other)
      other.is_a?(EXEL::Context) && table == other.table
    end

    def include?(values)
      @table.merge(values) == @table
    end

    private

    def serialized_context(table)
      file = Tempfile.new(SecureRandom.uuid, encoding: 'ascii-8bit')
      file.write(Marshal.dump(Context.new(table)))
      file.rewind
      file
    end

    def get_deferred(value)
      if deferred?(value)
        value = value.get(self)
      elsif value.is_a?(Array)
        value.map! { |v| get_deferred(v) }
      elsif value.is_a?(Hash)
        value.each { |k, v| value[k] = get_deferred(v) }
      end

      value
    end

    def deferred?(value)
      value.is_a?(DeferredContextValue)
    end
  end
end
