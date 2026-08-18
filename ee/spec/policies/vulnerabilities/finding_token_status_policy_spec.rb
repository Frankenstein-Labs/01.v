# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::FindingTokenStatusPolicy, feature_category: :secret_detection do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project) }
  let_it_be(:finding) { create(:vulnerabilities_finding, vulnerability: vulnerability) }
  let_it_be(:token_status) { create(:finding_token_status, finding: finding, project: project) }

  subject { described_class.new(user, token_status) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  context "when the current user has developer access to the vulnerability's project" do
    before_all do
      project.add_developer(user)
    end

    it { is_expected.to be_allowed(:read_finding_token_status) }
  end

  context "when the current user does not have developer access to the vulnerability's project" do
    it { is_expected.to be_disallowed(:read_finding_token_status) }
  end
end
