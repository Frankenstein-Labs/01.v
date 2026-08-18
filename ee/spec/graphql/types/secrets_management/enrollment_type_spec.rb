# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['SecretsManagerEnrollment'], feature_category: :secrets_management do
  let(:expected_fields) { %i[namespace beta] }

  specify do
    expect(described_class.graphql_name).to eq('SecretsManagerEnrollment')
    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'requires authorization to read the enrollment' do
    expect(described_class).to require_graphql_authorizations(:read_secrets_manager_enrollment)
  end

  it 'exposes beta as non-nullable' do
    expect(described_class.fields['beta'].type.to_type_signature).to eq('Boolean!')
  end
end
