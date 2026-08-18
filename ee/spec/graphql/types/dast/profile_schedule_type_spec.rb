# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DastProfileSchedule'], feature_category: :dynamic_application_security_testing do
  include GraphqlHelpers

  let_it_be(:fields) { %i[id active startsAt timezone nextRunAt cadence ownerValid] }
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:object) { create(:dast_profile_schedule, project: project, owner: user) }

  before do
    stub_licensed_features(security_on_demand_scans: true)
  end

  specify { expect(described_class.graphql_name).to eq('DastProfileSchedule') }

  it { expect(described_class).to have_graphql_fields(fields) }

  describe 'startsAt field' do
    it 'converts the startsAt to the timezone' do
      expect(resolve_field(:starts_at, object, current_user: user)).to eq(object.starts_at.in_time_zone(object.timezone))
    end
  end

  describe 'nextRunAt field' do
    it 'converts the nextRunAt to the timezone' do
      expect(resolve_field(:next_run_at, object, current_user: user)).to eq(object.next_run_at.in_time_zone(object.timezone))
    end
  end

  describe 'ownerValid' do
    it 'returns if the owner is valid' do
      expect(resolve_field(:owner_valid, object, current_user: user)).to eq(object.owner_valid?)
    end
  end
end
