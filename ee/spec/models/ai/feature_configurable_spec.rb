# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::FeatureConfigurable, feature_category: :"self-hosted_models" do
  # Create a test class that includes the concern
  let(:included_class) do
    Class.new do
      include ::Ai::FeatureConfigurable
    end
  end

  subject(:included_instance) { included_class.new }

  describe '#self_hosted?' do
    it 'raises NotImplementedError when not implemented' do
      expect { included_instance.self_hosted? }.to raise_error(
        NotImplementedError,
        "#self_hosted? method must be implemented"
      )
    end
  end

  describe '#disabled?' do
    it 'raises NotImplementedError when not implemented' do
      expect { included_instance.disabled? }.to raise_error(
        NotImplementedError,
        "#disabled? method must be implemented"
      )
    end
  end

  describe '#vendored?' do
    it 'raises NotImplementedError when not implemented' do
      expect { included_instance.vendored? }.to raise_error(
        NotImplementedError,
        "#vendored? method must be implemented"
      )
    end
  end

  describe '#model_metadata_params' do
    it 'raises NotImplementedError when not implemented' do
      expect { included_instance.model_metadata_params }.to raise_error(
        NotImplementedError,
        "#model_metadata_params method must be implemented"
      )
    end
  end

  describe '#model_request_params' do
    it 'raises NotImplementedError when not implemented' do
      expect { included_instance.model_request_params }.to raise_error(
        NotImplementedError,
        "#model_request_params method must be implemented"
      )
    end
  end

  describe '#base_url' do
    it 'raises NotImplementedError when not implemented' do
      expect { included_instance.base_url }.to raise_error(
        NotImplementedError,
        "#base_url method must be implemented"
      )
    end
  end

  describe '#user_model_selection_available?' do
    it 'returns true by default' do
      expect(included_instance.user_model_selection_available?).to be true
    end
  end
end
