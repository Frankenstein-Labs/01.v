# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe 'application_setting_secrets_manager_settings.json', feature_category: :secrets_management do
  let(:schema_path) do
    Rails.root.join('ee/app/validators/json_schemas/application_setting_secrets_manager_settings.json')
  end

  let(:schema) { JSONSchemer.schema(schema_path) }

  let(:base_settings) do
    {
      'project_secrets_limit' => 100,
      'group_secrets_limit' => 500
    }
  end

  it 'accepts valid settings' do
    expect(schema.valid?(base_settings)).to be true
  end

  it 'accepts zero (unlimited) values' do
    settings = base_settings.merge(
      'project_secrets_limit' => 0,
      'group_secrets_limit' => 0
    )

    expect(schema.valid?(settings)).to be true
  end

  it 'rejects negative values' do
    settings = base_settings.merge('project_secrets_limit' => -1)

    expect(schema.valid?(settings)).to be false
  end

  it 'rejects additional properties' do
    settings = base_settings.merge('extra' => 'value')

    expect(schema.valid?(settings)).to be false
  end
end
