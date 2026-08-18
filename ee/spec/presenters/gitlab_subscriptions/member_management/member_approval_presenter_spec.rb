# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::MemberApprovalPresenter, feature_category: :seat_cost_management do
  let(:project_namespace) { build_stubbed(:project_namespace) }
  let(:project) { build_stubbed(:project, project_namespace: project_namespace) }
  let(:group) { build_stubbed(:group) }
  let(:namespace) { project.project_namespace }
  let(:member_approval) do
    build_stubbed(
      :gitlab_subscription_member_management_member_approval,
      member_namespace: namespace
    )
  end

  let(:user) { build_stubbed(:user) }
  let(:presenter) { member_approval.present(current_user: user) }

  describe '#human_new_access_level' do
    subject(:human_new_access_level) { presenter.human_new_access_level }

    it 'returns the human-readable string for new access level' do
      expect(::Gitlab::Access).to receive(:human_access).with(member_approval.new_access_level).and_return('Owner')

      expect(human_new_access_level).to eq('Owner')
    end
  end

  describe '#human_old_access_level' do
    subject(:human_old_access_level) { presenter.human_old_access_level }

    it 'returns the human-readable string for old access level' do
      expect(::Gitlab::Access).to receive(:human_access).with(member_approval.old_access_level).and_return('Developer')

      expect(human_old_access_level).to eq('Developer')
    end
  end

  context 'when member_namespace is a Group' do
    let(:namespace) { group }

    it 'has the expected attributes' do
      expect(presenter.source_id).to eq(group.id)
      expect(presenter.source_web_url).to eq(group.web_url)
    end
  end

  context 'when member_namespace is a ProjectNamespace' do
    it 'has the expected attributes' do
      expect(presenter.source_id).to eq(project.id)
      expect(presenter.source_web_url).to eq(project.web_url)
    end
  end

  describe '#source_name' do
    subject(:source_name) { presenter.source_name }

    it 'returns the name of the namespace' do
      expect(source_name).to eq(member_approval.member_namespace.name)
    end
  end
end
