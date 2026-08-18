# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProtectDefaultBranchService do
  let(:service) { described_class.new(project) }
  let(:project) { create(:project) }

  shared_context 'has security_policy_project' do
    before do
      allow(Security::OrchestrationPolicyConfiguration)
        .to receive(:exists?)
              .and_return(true)
    end
  end

  describe '#code_owner_approval_required?' do
    context 'when licensed feature is not available' do
      it 'is falsey' do
        expect(service.code_owner_approval_required?).to be_falsey
      end
    end

    context 'when licensed feature is available' do
      before do
        stub_licensed_features(code_owner_approval_required: true)
        allow(project.namespace)
          .to receive(:default_branch_protection_settings)
                .and_return(Gitlab::Access::BranchProtection.protection_none)
      end

      it 'calls code_owner_approval_required? of Gitlab::Access::DefaultBranchProtection and returns correct value',
        :aggregate_failures do
        expect_next_instance_of(Gitlab::Access::DefaultBranchProtection) do |instance|
          expect(instance).to receive(:code_owner_approval_required?)
        end

        expect(service.code_owner_approval_required?).to be_falsey
      end
    end
  end

  describe '#protect_branch?' do
    context 'when project has security_policy_project' do
      include_context 'has security_policy_project'

      it 'returns true' do
        expect(service.protect_branch?).to be(true)
      end
    end

    it { expect(service.protect_branch?).to be(false) }
  end

  describe '#push_access_level' do
    context 'when project has security_policy_project' do
      include_context 'has security_policy_project'

      it 'returns NO_ACCESS access level' do
        expect(service.push_access_level).to eq(Gitlab::Access::NO_ACCESS)
      end
    end

    context 'when project does not have security_policy_project' do
      before do
        allow(project.namespace)
          .to receive(:default_branch_protection_settings)
                .and_return(Gitlab::Access::BranchProtection.protection_partial)
      end

      it 'returns DEVELOPER access level' do
        expect(service.push_access_level).to eq(Gitlab::Access::DEVELOPER)
      end
    end
  end

  describe '#merge_access_level' do
    context 'when project has security_policy_project' do
      include_context 'has security_policy_project'

      it 'returns Maintainer access level' do
        expect(service.merge_access_level).to eq(Gitlab::Access::MAINTAINER)
      end
    end

    context 'when project does not have security_policy_project' do
      before do
        allow(project.namespace)
          .to receive(:default_branch_protection_settings)
                .and_return(Gitlab::Access::BranchProtection.protected_against_developer_pushes)
      end

      it 'returns DEVELOPER access level' do
        expect(service.merge_access_level).to eq(Gitlab::Access::DEVELOPER)
      end
    end
  end
end
