# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Concerns::Loggable, feature_category: :global_search do
  let(:mock_logger) { instance_double(::Gitlab::ActiveContext::Logger, info: nil) }

  before do
    allow(::ActiveContext::Config).to receive(:logger).and_return(mock_logger)
  end

  def make_loggable_class(name: nil)
    klass = Class.new do
      include Ai::ActiveContext::Concerns::Loggable

      def log_test(**params)
        logger.info(build_structured_payload(**params))
      end
    end
    klass.define_singleton_method(:name) { name } if name
    klass
  end

  subject(:instance) { make_loggable_class(name: 'MyActiveContextService').new }

  describe 'structured log payload' do
    it 'emits class_name and not the deprecated class field', :aggregate_failures do
      instance.log_test(message: 'test')

      expect(mock_logger).to have_received(:info).with(
        hash_including('class_name' => 'MyActiveContextService', 'message' => 'test')
      )
      expect(mock_logger).to have_received(:info).with(hash_excluding('class'))
    end

    it 'merges extra params' do
      instance.log_test(message: 'test', project_id: 1)

      expect(mock_logger).to have_received(:info).with(
        hash_including('class_name' => 'MyActiveContextService', 'message' => 'test', 'project_id' => 1)
      )
    end

    it 'handles anonymous classes' do
      make_loggable_class.new.log_test(message: 'test')

      expect(mock_logger).to have_received(:info).with(
        hash_including('class_name' => Gitlab::Loggable::ANONYMOUS)
      )
    end
  end

  describe '#logger' do
    it 'returns the ActiveContext configured logger' do
      expect(instance.send(:logger)).to eq(mock_logger)
    end
  end
end
