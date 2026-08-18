# frozen_string_literal: true

require 'spec_helper'

# Unit coverage for the check class behind the prevent-pushing policy block.
# The service and request specs exercise this indirectly; these examples pin
# down `alters_push_access_levels?`/`alters_allow_force_push?` directly, since
# the regression (issue #602530) was a merge-only edit being wrongly blocked
# because callers echo the full push-access state back unchanged.
RSpec.describe EE::ProtectedBranches::ForcePushChangesBlockedByPolicy::ForcePushCheck,
  feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let(:branch_name) { 'feature' }
  let(:protected_branch) { create(:protected_branch, name: branch_name, project: project) }
  let(:existing_push_access_level) { protected_branch.push_access_levels.first }
  let(:user) { project.first_owner }

  let(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  include_context 'with approval security policy preventing force pushing'

  subject(:check) { described_class.new(protected_branch, params, user) }

  describe '#violated?' do
    context 'when push access levels echo the stored levels unchanged' do
      let(:params) do
        {
          merge_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }],
          push_access_levels_attributes: [
            { id: existing_push_access_level.id, access_level: existing_push_access_level.access_level }
          ]
        }
      end

      it { is_expected.not_to be_violated }
    end

    context 'when push access levels are omitted entirely' do
      let(:params) do
        { merge_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }] }
      end

      it { is_expected.not_to be_violated }
    end

    context 'when an existing push access level is changed to a different role' do
      let(:params) do
        { push_access_levels_attributes: [{ id: existing_push_access_level.id, access_level: Gitlab::Access::DEVELOPER }] }
      end

      it { is_expected.to be_violated }
    end

    context 'when a new push access level is added' do
      let(:params) do
        {
          push_access_levels_attributes: [
            { id: existing_push_access_level.id, access_level: existing_push_access_level.access_level },
            { access_level: Gitlab::Access::DEVELOPER }
          ]
        }
      end

      it { is_expected.to be_violated }
    end

    context 'when an existing push access level is destroyed' do
      let(:params) do
        {
          push_access_levels_attributes: [
            { id: existing_push_access_level.id, access_level: existing_push_access_level.access_level, _destroy: true }
          ]
        }
      end

      it { is_expected.to be_violated }
    end

    context 'when allow_force_push echoes the stored value' do
      let(:params) { { allow_force_push: protected_branch.allow_force_push } }

      it { is_expected.not_to be_violated }
    end

    context 'when allow_force_push differs from the stored value' do
      let(:params) { { allow_force_push: !protected_branch.allow_force_push } }

      it { is_expected.to be_violated }
    end
  end

  describe '.check!' do
    # A genuine push-access change ensures `forbidden_params?` passes and `blocked?` is exercised.
    let(:params) do
      {
        push_access_levels_attributes: [
          { id: existing_push_access_level.id, access_level: Gitlab::Access::DEVELOPER }
        ]
      }
    end

    context 'when the policy cannot be enforced' do
      shared_examples 'an unenforceable policy' do
        it 'does not raise a policy violation' do
          expect { described_class.check!(protected_branch, params, user) }.not_to raise_error
        end
      end

      context 'when security orchestration policies are not licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'an unenforceable policy'
      end

      context 'when the policy is disabled' do
        before do
          approval_policy_preventing_force_pushing.update!(enabled: false)
        end

        it_behaves_like 'an unenforceable policy'
      end

      context 'when a non-approval policy contains the prevent-pushing setting' do
        before do
          # Bypass type-specific JSON schema validation to model legacy or corrupt persisted data.
          approval_policy_preventing_force_pushing.update_column(
            :type, Security::Policy.types.fetch('scan_execution_policy'))
        end

        it_behaves_like 'an unenforceable policy'
      end
    end

    context 'when the push access levels are genuinely changed' do
      it 'raises a policy violation' do
        expect { described_class.check!(protected_branch, params, user) }
          .to raise_error(::EE::ProtectedBranches::BasePolicyCheck::PolicyViolationError)
      end
    end

    context 'when only merge access changes and push access is echoed unchanged' do
      let(:params) do
        {
          merge_access_levels_attributes: [{ access_level: Gitlab::Access::DEVELOPER }],
          push_access_levels_attributes: [
            { id: existing_push_access_level.id, access_level: existing_push_access_level.access_level }
          ]
        }
      end

      it 'does not raise' do
        expect { described_class.check!(protected_branch, params, user) }.not_to raise_error
      end
    end
  end
end
