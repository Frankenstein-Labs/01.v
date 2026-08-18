# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokenServiceBase, feature_category: :secret_detection do
  describe 'abstract methods' do
    it 'raises NotImplementedError for .finding_type' do
      expect { described_class.finding_type }
        .to raise_error(NotImplementedError, /must implement \.finding_type/)
    end

    it 'raises NotImplementedError for .token_status_model' do
      expect { described_class.token_status_model }
        .to raise_error(NotImplementedError, /must implement \.token_status_model/)
    end

    it 'raises NotImplementedError for .unique_by_column' do
      expect { described_class.unique_by_column }
        .to raise_error(NotImplementedError, /must implement \.unique_by_column/)
    end
  end
end
