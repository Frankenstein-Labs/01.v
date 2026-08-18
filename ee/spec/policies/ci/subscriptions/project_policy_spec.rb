# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Subscriptions::ProjectPolicy, feature_category: :compliance_management do
  let_it_be_with_reload(:project) { create(:project, :small_repo, :public) }
  let_it_be(:upstream_project) { create(:project, :small_repo, :public) }
  let_it_be(:user) { create(:user) }
  let_it_be(:subscription) do
    create(:ci_subscriptions_project, downstream_project: project, upstream_project: upstream_project)
  end

  subject(:policy) { described_class.new(user, subscription) }

  context 'when user does not have maintainer access to project' do
    it { is_expected.to be_disallowed(:delete_project_subscription) }
  end

  context 'when user has no permissions' do
    it { is_expected.to be_disallowed(:read_project_subscription) }
  end

  context 'when user is maintainer for the downstream project' do
    before_all do
      project.add_maintainer(user)
    end

    it { is_expected.to be_allowed(:read_project_subscription) }
    it { is_expected.to be_allowed(:delete_project_subscription) }
  end

  context 'when user is maintainer for the upstream project' do
    before_all do
      upstream_project.add_maintainer(user)
    end

    it { is_expected.to be_allowed(:read_project_subscription) }
    it { is_expected.to be_disallowed(:delete_project_subscription) }
  end

  context 'when user is a developer for the upstream project' do
    before_all do
      upstream_project.add_developer(user)
    end

    it { is_expected.to be_disallowed(:read_project_subscription) }
  end

  context 'when user is developer for both projects' do
    before_all do
      project.add_developer(user)
      upstream_project.add_developer(user)
    end

    it { is_expected.to be_disallowed(:read_project_subscription) }
    it { is_expected.to be_disallowed(:delete_project_subscription) }
  end
end
