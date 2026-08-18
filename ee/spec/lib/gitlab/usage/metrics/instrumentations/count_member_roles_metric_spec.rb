# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountMemberRolesMetric, feature_category: :permissions do
  before do
    create(:member_role)
  end

  context 'with a correct instrumented metric value and query',
    quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/450232' do
    it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
      let(:expected_value) { 1 }
      let(:expected_query) { "SELECT COUNT(\"member_roles\".\"id\") FROM \"member_roles\"" }
    end
  end
end
