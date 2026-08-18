# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ExternalStatusCheckPolicy, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:external_status_check) { create(:external_status_check, project: project) }

  subject { described_class.new(user, external_status_check) }

  context 'when user can admin project' do
    let(:user) { project.creator }

    it { is_expected.to be_allowed(:read_external_status_check) }
  end

  context 'when user is an non-member admin' do
    let_it_be(:user) { create(:user, :admin) }

    context 'when admin mode is enabled', :enable_admin_mode do
      it { is_expected.to be_allowed(:read_external_status_check) }
    end

    context 'when admin mode is disabled' do
      it { is_expected.to be_disallowed(:read_external_status_check) }
    end
  end

  context 'when user cannot admin project' do
    let_it_be(:user) { create(:user) }

    before_all do
      project.add_developer(user)
    end

    it { is_expected.to be_disallowed(:read_external_status_check) }
  end
end
