# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['LdapAdminRoleLink'], feature_category: :permissions do
  it { expect(described_class.graphql_name).to eq('LdapAdminRoleLink') }

  describe 'fields' do
    let(:fields) do
      %i[
        id created_at admin_member_role provider filter cn
        sync_status sync_started_at sync_ended_at last_successful_sync_at
        sync_error
      ]
    end

    it { expect(described_class).to have_graphql_fields(fields) }
  end
end
