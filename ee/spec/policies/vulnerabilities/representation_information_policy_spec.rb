# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::RepresentationInformationPolicy, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability_representation_information) do
    create(:vulnerability_representation_information,
      vulnerability: vulnerability,
      project: project,
      resolved_in_commit_sha: 'abc123def456')
  end

  subject { described_class.new(user, vulnerability_representation_information) }

  context 'when the security_dashboard feature is enabled' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the current user has developer access to the vulnerability project' do
      before_all do
        project.add_developer(user)
      end

      it { is_expected.to be_allowed(:read_vulnerability_representation_information) }
    end

    context 'when the current user does not have developer access to the vulnerability project' do
      it { is_expected.to be_disallowed(:read_vulnerability_representation_information) }
    end
  end

  context 'when the security_dashboard feature is disabled' do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    it { is_expected.to be_disallowed(:read_vulnerability_representation_information) }
  end
end
