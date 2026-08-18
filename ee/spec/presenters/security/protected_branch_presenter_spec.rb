# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProtectedBranchPresenter, feature_category: :security_policy_management do
  let(:presenter) { protected_branch.present(current_user: current_user, presenter_class: described_class) }
  let(:protected_branch) { build(:protected_branch) }
  let(:current_user) { build(:user) }
  let(:project) { build(:project) }
  let_it_be(:group) { create_default(:group) }

  describe 'permissions checks' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability)
        .to receive(:allowed?)
              .with(current_user, ability, protected_branch)
              .and_return(allowed)
    end

    describe '#can_destroy?' do
      let(:ability) { :destroy_protected_branch }

      context 'when user has no ability to destroy_protected_branch' do
        let(:allowed) { false }

        subject { presenter.can_destroy? }

        it { is_expected.to be_falsey }
      end

      context 'when user has ability to destroy_protected_branch' do
        let(:allowed) { true }

        subject { presenter.can_destroy? }

        context 'when the branch is protected from deletion' do
          before do
            protected_branch.protected_from_deletion = true
          end

          it { is_expected.to be_falsey }
        end

        context 'when the branch is not protected from deletion' do
          it { is_expected.to be_truthy }
        end
      end
    end

    describe '#can_update?' do
      let(:ability) { :update_protected_branch }

      subject { presenter.can_update?(project) }

      context 'when user has no ability to update_protected_branch' do
        let(:allowed) { false }

        it { is_expected.to be_falsey }
      end

      context 'when user has ability to update_protected_branch' do
        let(:allowed) { true }

        context 'when the branch is not protected from deletion' do
          context 'when the branch is inherited' do
            let(:protected_branch) { build(:protected_branch, namespace_id: group.id) }

            it { is_expected.to be_falsey }
          end

          context 'when the branch is not inherited' do
            it { is_expected.to be_truthy }
          end
        end
      end
    end

    describe '#can_unprotect_branch?' do
      let(:ability) { :destroy_protected_branch }

      subject { presenter.can_unprotect_branch? }

      context 'when user has no ability to destroy_protected_branch' do
        let(:allowed) { false }

        it { is_expected.to be_falsey }
      end

      context 'when user has ability to destroy_protected_branch' do
        let(:allowed) { true }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#entity_inherited??' do
    let(:protected_branch_entity) { project }

    subject { presenter.entity_inherited?(protected_branch_entity) }

    context 'when protected_branch_entity is a Project' do
      context 'when protected_branch is not at group level' do
        it { is_expected.to be_falsey }
      end

      context 'when protected_branch is at group level' do
        let(:protected_branch) { build(:protected_branch, namespace_id: group.id) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when protected_branch_entity is a Group' do
      let(:protected_branch_entity) { group }

      it { is_expected.to be_falsey }
    end
  end
end
