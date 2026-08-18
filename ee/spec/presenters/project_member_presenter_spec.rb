# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectMemberPresenter, feature_category: :groups_and_projects do
  let(:user) { double(:user) }
  let(:project) { double(:project) }
  let(:project_member) { double(:project_member, source: project, user: user) }
  let(:presenter) { described_class.new(project_member, current_user: user) }

  describe '#group_sso?' do
    let(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- persisted user_id needed for creating a saml_identity
    let(:saml_provider) { create(:saml_provider) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- persisted saml_provider_id needed for creating a saml_identity
    let(:group) { saml_provider.group }
    let(:project) { build_stubbed(:project, namespace: group) }

    context 'when a project_member does not have a user' do
      let(:project_member) { build_stubbed(:project_member, source: project, user: nil) }

      it 'returns false' do
        expect(project_member.user).not_to be_present
        expect(presenter.group_sso?).to be(false)
      end
    end

    context 'when a project_member has a user, without a group_namespace (is a personal project)' do
      let(:project) { build_stubbed(:project, namespace: user.namespace) }

      it 'returns false' do
        expect(project).to receive(:root_ancestor).and_return(project)
        expect(project).to receive(:group_namespace?).and_return(false)
        expect(presenter.group_sso?).to be(false)
      end
    end

    context 'when a project_member has a user, within a group namespace' do
      before do
        create(:group_saml_identity, saml_provider: saml_provider, user: user) # rubocop:disable RSpec/FactoryBot/AvoidCreate -- searches dB and prevents FK errors
      end

      it 'returns true' do
        expect(presenter.group_sso?).to be(true)
      end
    end
  end

  describe '#group_managed_account?' do
    it 'returns `false`' do
      expect(presenter.group_managed_account?).to be(false)
    end
  end

  describe '#can_update?' do
    context 'when user cannot update project_member' do
      before do
        allow(project_member).to receive(:owner?).and_return(false)
        allow(presenter).to receive(:can?).with(user, :update_project_member, presenter).and_return(false)
      end

      context 'when user can override_project_member' do
        before do
          allow(presenter).to receive(:can?).with(user, :override_project_member, presenter).and_return(true)
        end

        it { expect(presenter.can_update?).to be(true) }
      end

      context 'when user cannot override_project_member' do
        before do
          allow(presenter).to receive(:can?).with(user, :override_project_member, presenter).and_return(false)
        end

        it { expect(presenter.can_update?).to be(false) }
      end
    end
  end

  describe '#can_ban?' do
    it { expect(presenter.can_ban?).to be(false) }
  end

  describe '#can_unban?' do
    it { expect(presenter.can_unban?).to be(false) }
  end
end
