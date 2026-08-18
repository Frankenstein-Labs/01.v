# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['SecretsManagementAction'], feature_category: :secrets_management do
  specify { expect(described_class.graphql_name).to eq('SecretsManagementAction') }

  it 'exposes all the secrets management action values' do
    expect(described_class.values.keys).to contain_exactly('READ', 'READ_VALUE', 'WRITE', 'DELETE')
  end

  it 'maps each value to its backing action', :aggregate_failures do
    actions = ::SecretsManagement::BaseSecretsPermission::ACTIONS

    expect(described_class.values['READ'].value).to eq(actions[:read])
    expect(described_class.values['READ_VALUE'].value).to eq(actions[:read_value])
    expect(described_class.values['WRITE'].value).to eq(actions[:write])
    expect(described_class.values['DELETE'].value).to eq(actions[:delete])
  end
end
