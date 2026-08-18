# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRuleable, feature_category: :source_code_management do
  let(:push_rule_klass) do
    Class.new do
      def self.validates(*args, **options)
        # No-op for testing
      end

      def self.validate(*args, **options)
        # No-op for testing
      end

      include PushRuleable
    end
  end

  describe '#available?' do
    it 'raises NotImplementedError when not implemented by subclass' do
      instance = push_rule_klass.new

      expect { instance.available?(:some_feature) }
        .to raise_error(NotImplementedError, /must implement #available\? method/)
    end
  end
end
