# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::CConanTxt, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('c')
  end
end
