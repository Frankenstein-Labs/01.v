# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PathLock'], feature_category: :source_code_management do
  it { expect(described_class.graphql_name).to eq('PathLock') }

  it { expect(described_class).to require_graphql_authorizations(:read_path_locks) }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:id, :path, :user, :user_permissions, :created_at)
  end
end
