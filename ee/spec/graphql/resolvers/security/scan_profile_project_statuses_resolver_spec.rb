# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::ScanProfileProjectStatusesResolver, feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group, scan_type: :sast) }
  let_it_be(:status_record) do
    create(:scan_profile_project_status, project: project, scan_profile: scan_profile,
      status: :success, last_scan_at: 1.day.ago)
  end

  before do
    stub_licensed_features(security_scan_profiles: true)
  end

  specify do
    expect(described_class).to have_nullable_graphql_type(Types::Security::ScanProfileProjectStatusType)
  end

  describe '#resolve' do
    subject(:resolved) { sync(resolve(described_class, obj: project, ctx: { current_user: current_user }).to_a) }

    it 'returns scan profile project statuses for the project' do
      expect(resolved).to contain_exactly(status_record)
    end

    context 'when project has no statuses' do
      let_it_be(:empty_project) { create(:project, group: group) }

      subject(:resolved) do
        sync(resolve(described_class, obj: empty_project, ctx: { current_user: current_user }).to_a)
      end

      it 'returns an empty array' do
        expect(resolved).to be_empty
      end
    end
  end
end
