# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::FindingTokenStatusPolicy, feature_category: :secret_detection do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:security_scan) { create(:security_scan, project: project, scan_type: :secret_detection) }
  let_it_be(:finding) { create(:security_finding, scan: security_scan) }
  let_it_be(:token_status) { create(:security_finding_token_status, security_finding: finding) }

  subject { described_class.new(user, token_status) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  context 'when user has project access' do
    before_all do
      project.add_developer(user)
    end

    it { is_expected.to be_allowed(:read_finding_token_status) }
  end

  context 'when user does not have project access' do
    it { is_expected.to be_disallowed(:read_finding_token_status) }
  end
end
