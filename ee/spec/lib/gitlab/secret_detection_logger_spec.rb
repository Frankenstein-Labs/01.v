# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SecretDetectionLogger, feature_category: :secret_detection do
  subject { described_class.new('/dev/null') }

  it_behaves_like 'a json logger', {}

  describe '#file_name_noext' do
    it 'returns log file name without extension' do
      expect(described_class.file_name_noext).to eq('secret_push_protection')
    end
  end
end
