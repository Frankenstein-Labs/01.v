# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['BranchProtection'], feature_category: :source_code_management do
  include GraphqlHelpers

  subject { described_class }

  let(:fields) do
    %i[
      allow_force_push
      code_owner_approval_required
      merge_access_levels
      push_access_levels
      unprotect_access_levels
      modification_blocked_by_policy
      protected_from_push_by_security_policy
      warn_modification_blocked_by_policy
      warn_protected_from_push_by_security_policy
      is_group_level
    ]
  end

  it { is_expected.to have_graphql_fields(fields).only }

  describe '#modification_blocked_by_policy' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

    subject(:result) { resolve_field(:modification_blocked_by_policy, protected_branch, current_user: user) }

    before_all do
      project.add_maintainer(user)
    end

    it 'passes current_user to the model method' do
      expect(protected_branch).to receive(:modification_blocked_by_policy).with(user).and_call_original
      result
    end
  end

  describe '#warn_modification_blocked_by_policy' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

    subject(:result) { resolve_field(:warn_modification_blocked_by_policy, protected_branch, current_user: user) }

    before_all do
      project.add_maintainer(user)
    end

    it 'passes current_user to the model method' do
      expect(protected_branch).to receive(:warn_modification_blocked_by_policy).with(user).and_call_original
      result
    end
  end

  describe '#push_access_levels' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:protected_branch) do
      create(:protected_branch, project: project, default_push_level: false)
    end

    let_it_be(:push_access_level) { create(:protected_branch_push_access_level, protected_branch: protected_branch) }

    let(:protected_from_push_by_security_policy) { false }

    subject(:result) { resolve_field(:push_access_levels, protected_branch, current_user: user) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      allow(protected_branch).to receive(:protected_from_push_by_security_policy?)
        .and_return(protected_from_push_by_security_policy)
    end

    it 'returns the push access levels' do
      items = result.items.to_a

      expect(items).to contain_exactly(push_access_level)
    end

    context 'when protected from push by security policy' do
      let(:protected_from_push_by_security_policy) { true }

      it 'returns a NO_ACCESS push access level', :aggregate_failures do
        items = result.items

        expect(items).to be_an(Array)
        expect(items.size).to eq(1)
        expect(items.first).to be_a(ProtectedBranch::PushAccessLevel)
        expect(items.first.access_level).to eq(Gitlab::Access::NO_ACCESS)
        expect(items.first.protected_branch).to eq(protected_branch)
      end
    end
  end
end
