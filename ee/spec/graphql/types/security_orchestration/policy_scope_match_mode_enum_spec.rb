# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyScopeMatchMode'], feature_category: :security_policy_management do
  it 'exposes all match mode values' do
    expect(described_class.values.keys).to contain_exactly('ALL', 'ANY')
  end

  it 'has correct value mappings' do
    expect(described_class.values['ALL'].value).to eq('all')
    expect(described_class.values['ANY'].value).to eq('any')
  end
end
