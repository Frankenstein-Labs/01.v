# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['LdapAdminRoleSyncStatus'], feature_category: :permissions do
  specify { expect(described_class.graphql_name).to eq('LdapAdminRoleSyncStatus') }

  it 'exposes all the existing access levels' do
    expect(described_class.values.keys)
      .to include(*%w[NEVER_SYNCED QUEUED RUNNING SUCCESSFUL FAILED])
  end
end
