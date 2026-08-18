# frozen_string_literal: true

module EE
  module RspecMetadataValidator
    extend ActiveSupport::Concern

    class_methods do
      def keys_not_from_file
        super + ::Gitlab::Saas::FEATURES.map { |feature| :"saas_#{feature}" }
      end
    end
  end
end
