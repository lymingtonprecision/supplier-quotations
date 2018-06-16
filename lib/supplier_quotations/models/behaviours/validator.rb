module SupplierQuotations; module Models;
  module Validator
    def validators attr=:all
      @validators ||= {}

      if attr == :all
        @validators
      else
        @validators[attr] ||= []
      end
    end

    # Add a validation to a specific attribute
    #
    # Can either be called with an error message and block that returns
    # a true/false value:
    #
    #     # With a provided lambda/proc:
    #     validates 'price', 'must be a number',
    #       lambda {|v| (v || 0).kind_of? Numeric}
    #     # ... or with a block:
    #     validates('price', 'must be a number') {|v| (v || 0).kind_of? Numeric}
    #
    #     validate 'price' => 123
    #     #=> {'attribute' => 123}
    #     validate 'price' => 'abc'
    #     #=> {'price' => 'abc', 'errors' => {'price' => ['must be a number']}}
    #
    # Or with a block that takes the value and errors array for the attribute:
    #
    #     validates 'price' do |current_price, errors|
    #       current_price ||= 0
    #       errors << 'must be a number' unless current_price.kind_of? Numeric
    #     end
    #
    def validates attr=:all, error=:fromm_block, validator=:block, &block
      validator = block if validator == :block && block_given?

      if validator.arity == 1
        value_validation = validator
        validator = lambda {|value, errors|
          errors << error if value_validation.call(value) == false
        }
      end

      validators(attr) << validator
      return nil
    end

    def validate object
      errors = {}

      validators.each do |attr, validators|
        next unless object.has_key? attr

        attr_value = object.fetch attr
        attr_errors = errors[attr] ||= []

        validators.each do |validator|
          validator.call attr_value, attr_errors
        end
      end

      errors = errors.reject {|k,v| v.empty?}
      object = object.merge 'errors' => errors if errors.size > 0

      return object
    end
  end
end; end

