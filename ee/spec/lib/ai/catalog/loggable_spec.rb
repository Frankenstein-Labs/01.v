# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Loggable, feature_category: :workflow_catalog do
  let(:test_class) do
    Class.new do
      include Ai::Catalog::Loggable

      def self.name
        'Ai::Catalog::TestClass'
      end
    end
  end

  let(:instance) { test_class.new }

  describe '#ai_catalog_logger' do
    it 'builds a Ai::Catalog::Logger with default_attributes containing the class name' do
      logger = instance.ai_catalog_logger

      expect(logger.default_attributes).to match(hash_including('class_name' => 'Ai::Catalog::TestClass'))
      expect(logger).to be_a(Ai::Catalog::Logger)
    end
  end
end
