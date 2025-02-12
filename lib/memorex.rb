# frozen_string_literal: true

require_relative "memorex/memory"
require_relative "memorex/utils"
require_relative "memorex/version"

module Memorex
  # Convert a method to a memoized method
  #
  # Memorex does not support memoizing methods that accept arguments.
  #
  # @api public
  # @param method_name [Symbol] the name of the method to memoize
  # @return [Symbol] the name of the memoized method
  # @raise [ArgumentError] when the method is is not defined
  # @raise [ArgumentError] when the method is already memoized
  #
  # @example
  #   class State
  #     extend Memorex
  #
  #     memoize def id
  #       SecureRandom.uuid
  #     end
  #   end
  #
  def memoize(method_name)
    @_memorex_methods ||= Methods.clone.tap do |mod|
      const_set(:MemoizedMethods, mod)
      prepend(mod)
    end

    visibility = Utils.visibility(self, method_name)

    if Utils.method_defined?(@_memorex_methods, method_name)
      raise ArgumentError, "`#{method_name.inspect}` is already memoized"
    end

    @_memorex_methods.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
      #{visibility} def #{method_name}
        raise ArgumentError, "unsupported block argument" if block_given?

        cache = (@_memorex_cache ||= {})
        cache.fetch(:#{method_name}) do
          cache[:#{method_name}] = super()
        end
      end
    RUBY

    method_name
  end

  # @api private
  module Methods
    def initialize(*, **)
      @_memorex_cache = {}
      super
    end

    def freeze
      @_memorex_cache ||= {}
      super
    end
  end

  # This module provides a {#memorex} helper that can be used to manipulate the
  # memoization cache directly.
  module API
    # Used to manipulate the memoized cache directly
    #
    # @api public
    # @return [Memory]
    #
    # @example
    #   class State
    #     extend Memorex
    #     include Memorex::API
    #
    #     memoize def id
    #       SecureRandom.uuid
    #     end
    #
    #     def reset!
    #       memorex.clear
    #     end
    #   end
    def memorex
      ::Memorex::Memory.new(@_memorex_cache ||= {})
    end
  end
end
