# frozen_string_literal: true

module Ai
  module Catalog
    # Validates that a foundational flow resolver attribute (e.g. `noteable_resolver`) is either unset or a lambda
    # accepting exactly the keyword arguments it is invoked with. The expected keyword names are passed via the
    # `keywords:` validator option, since each resolver attribute is invoked with a
    # different set of keyword arguments.
    class ResolverValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        return if value.nil?
        return if valid_resolver?(value)

        record.errors.add(attribute, format(
          _("must be nil or a lambda accepting keyword arguments: %{keywords}"),
          keywords: required_keywords.join(', ')
        ))
      end

      def check_validity!
        keywords = options[:keywords]

        return if keywords.is_a?(Array) && keywords.all?(Symbol)

        raise ArgumentError, <<~ERROR
          `:keywords` must be an `Array[Symbol]` (got #{keywords.inspect}).

          Usage:
            validates :attribute_name, 'ai/catalog/resolver': { keywords: [:arg1, :arg0] }
        ERROR
      end

      private

      def valid_resolver?(value)
        return false unless value.is_a?(Proc) && value.lambda?

        parameters = value.parameters
        return false if parameters.any? { |type, _| type != :keyreq }

        parameters.map(&:last).sort == required_keywords
      end

      def required_keywords
        Array(options.fetch(:keywords)).sort
      end
    end
  end
end
