# frozen_string_literal: true

require 'spec_helper'

using RSpec::Parameterized::TableSyntax

RSpec.describe Ai::DuoWorkflow, feature_category: :ai_abstraction_layer do
  let_it_be(:current_org) { create(:common_organization) }
  let_it_be(:current_user) { create(:user, :admin) }
  let_it_be_with_reload(:service_account_user) { create(:user, :service_account) }
  let_it_be_with_reload(:doorkeeper_application) { create(:doorkeeper_application) }
  let_it_be(:organization) { create(:organization) }

  before do
    stub_current_organization(current_org)
  end

  describe '#enabled?' do
    where(:duo_workflow_license_available, :duo_enabled, :result) do
      true  | false | false
      false | false | false
      false | true  | false
      true  | true  | true
    end

    with_them do
      before do
        stub_licensed_features(ai_workflows: duo_workflow_license_available)
        stub_ee_application_setting(duo_features_enabled: duo_enabled)
      end

      it 'returns the expected result' do
        expect(described_class.enabled?).to eq(result)
      end
    end
  end

  describe '#connected?' do
    context 'when duo workflow is not enabled' do
      before do
        allow(described_class).to receive(:enabled?).and_return(false)
      end

      it 'returns not connected' do
        expect(described_class.connected?).to be(false)
      end
    end

    context 'when duo workflow is enabled' do
      where(:service_account, :oauth_app, :result) do
        nil                         | nil                           | false
        ref(:service_account_user)  | nil                           | false
        nil                         | ref(:doorkeeper_application)  | false
        ref(:service_account_user)  | ref(:doorkeeper_application)  | true
      end

      with_them do
        before do
          allow(described_class).to receive(:enabled?).and_return(true)
          Ai::Setting.for_organization(current_org).update!(duo_workflow_service_account_user: service_account,
            duo_workflow_oauth_application: oauth_app)
        end

        it 'returns the expected result' do
          expect(described_class.connected?).to be result
        end
      end
    end

    context 'with explicit organization' do
      before do
        allow(described_class).to receive(:enabled?).and_return(true)
        Ai::Setting.for_organization(organization).update!(
          duo_workflow_service_account_user: service_account_user,
          duo_workflow_oauth_application: doorkeeper_application
        )
      end

      it 'uses the organization settings row' do
        expect(described_class.connected?(organization: organization)).to be(true)
        expect(described_class.connected?).to be(false)
      end

      context 'when the organization settings row does not exist' do
        before do
          Ai::Setting.find_by(organization: organization).destroy!
        end

        it 'returns false without creating a settings row' do
          expect(described_class.connected?(organization: organization)).to be(false)
          expect(Ai::Setting.where(organization: organization).count).to eq(0)
        end
      end
    end
  end

  describe '#available?' do
    shared_examples 'returns not available' do
      it 'returns not available' do
        expect(described_class.available?).to be(false)
      end
    end

    shared_examples 'returns available' do
      it 'returns available' do
        expect(described_class.available?).to be(true)
      end
    end

    context 'when duo workflow is not connected' do
      before do
        allow(described_class).to receive(:connected?).and_return(false)
      end

      it_behaves_like 'returns not available'
    end

    context 'when duo workflow is connected' do
      before do
        allow(described_class).to receive(:connected?).and_return(true)
        Ai::Setting.for_organization(current_org).update!(
          duo_workflow_service_account_user: service_account_user,
          duo_workflow_oauth_application: doorkeeper_application
        )
      end

      context 'with invalid configurations' do
        context 'when service account is blocked' do
          before do
            service_account_user.block
          end

          after do
            service_account_user.activate
          end

          it_behaves_like 'returns not available'
        end

        context 'when service account does not have composite identity enforced' do
          before do
            service_account_user.composite_identity_enforced = false
          end

          after do
            service_account_user.composite_identity_enforced = true
          end

          it_behaves_like 'returns not available'
        end

        context 'when oauth_app does not have dynamic user scope' do
          it_behaves_like 'returns not available'
        end
      end

      context 'with valid configuration' do
        context 'when oauth_app has dynamic user scope' do
          before do
            allow(described_class).to receive(:connected?).and_return(true)
            doorkeeper_application.update!(scopes: [::Gitlab::Auth::DYNAMIC_USER])
            service_account_user.update!(composite_identity_enforced: true)
          end

          it_behaves_like 'returns available'
        end
      end
    end

    context 'with explicit organization' do
      before do
        allow(described_class).to receive(:connected?).and_call_original
        allow(described_class).to receive(:enabled?).and_return(true)
        service_account_user.update!(composite_identity_enforced: true)
        doorkeeper_application.update!(scopes: [::Gitlab::Auth::DYNAMIC_USER])
        Ai::Setting.for_organization(organization).update!(
          duo_workflow_service_account_user: service_account_user,
          duo_workflow_oauth_application: doorkeeper_application
        )
      end

      it 'uses the organization settings row' do
        expect(described_class.available?(organization: organization)).to be(true)
        expect(described_class.available?).to be(false)
      end
    end
  end

  describe '#ensure_service_account_blocked!' do
    let_it_be(:current_user) { create(:user, :admin) }
    let_it_be_with_reload(:blocked_service_account) { create(:user, :service_account, :blocked) }
    let_it_be(:service_account_not_found) { Struct.new(:id).new(999999) }

    context 'with service_account set in application settings' do
      where(:service_account, :expected_service_class, :expected_status, :expected_message) do
        ref(:service_account_user) | ::Users::BlockService | true | nil
        ref(:blocked_service_account) | nil | true | "Service account already blocked. Nothing to do."
      end

      with_them do
        before do
          Ai::Setting.for_organization(current_org).update!(duo_workflow_service_account_user_id: service_account&.id)
        end

        it 'conditionally block the service account', :aggregate_failures do
          if expected_service_class
            expect_next_instance_of(expected_service_class, current_user) do |instance|
              expect(instance).to receive(:execute).with(service_account).and_call_original
            end
          end

          response = described_class.ensure_service_account_blocked!(current_user: current_user)

          expect(response.success?).to be(expected_status)
          expect(response.message).to be(expected_message)
        end
      end
    end

    context 'with service_account set as argument' do
      it 'conditionally blocks the given service account', :aggregate_failures do
        expect(service_account_user.blocked?).to be(false)

        response = described_class.ensure_service_account_blocked!(
          current_user: current_user,
          service_account: service_account_user
        )

        expect(response.success?).to be(true)
        expect(service_account_user.blocked?).to be(true)
      end
    end
  end

  describe '#duo_agent_platform_available?' do
    let(:application_setting) { instance_double(Ai::Setting) }
    let(:duo_agent_platform_enabled) { nil }
    let(:ai_setting) { ::Ai::Setting.for_organization(current_org) }
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    context 'when on GitLab.com (SaaS)', :saas do
      context 'when container is nil' do
        subject(:duo_agent_platform_available) { described_class.duo_agent_platform_available?(nil) }

        it { is_expected.to be false }
      end

      context 'when container has duo_agent_platform_enabled is false' do
        before do
          Ai::NamespaceSetting.create!(namespace: group, feature_settings: { duo_agent_platform_enabled: false })
        end

        subject(:duo_agent_platform_available) { described_class.duo_agent_platform_available?(group) }

        it { is_expected.to be false }
      end

      context 'when container has duo_agent_platform_enabled is true' do
        before do
          Ai::NamespaceSetting.create!(namespace: group, feature_settings: { duo_agent_platform_enabled: true })
        end

        subject(:duo_agent_platform_available) { described_class.duo_agent_platform_available?(group) }

        it { is_expected.to be true }
      end

      context 'when container is a project and parent has duo_agent_platform_enabled is true' do
        before do
          Ai::NamespaceSetting.create!(namespace: group, feature_settings: { duo_agent_platform_enabled: true })
        end

        subject(:duo_agent_platform_available) { described_class.duo_agent_platform_available?(project) }

        it { is_expected.to be true }
      end

      context 'when container is a project and parent has duo_agent_platform_enabled is false' do
        before do
          Ai::NamespaceSetting.create!(namespace: group, feature_settings: { duo_agent_platform_enabled: false })
        end

        subject(:duo_agent_platform_available) { described_class.duo_agent_platform_available?(project) }

        it { is_expected.to be false }
      end
    end

    context 'when on a self-managed or dedicated instance' do
      before do
        ai_setting.update!(feature_settings: { duo_agent_platform_enabled: duo_agent_platform_enabled })
      end

      context 'when application setting is true' do
        let(:duo_agent_platform_enabled) { true }

        subject(:duo_agent_platform_available) { described_class.duo_agent_platform_available? }

        it { is_expected.to be true }
      end

      context 'when application setting is false' do
        let(:duo_agent_platform_enabled) { false }

        subject(:duo_agent_platform_available) { described_class.duo_agent_platform_available? }

        it { is_expected.to be false }
      end

      context 'with container parameter (ignored on self-managed)' do
        let(:group) { create(:group) }
        let(:duo_agent_platform_enabled) { true }

        subject(:duo_agent_platform_available) { described_class.duo_agent_platform_available?(group) }

        it { is_expected.to be true }
      end
    end
  end

  describe '#duo_agent_platform_available_for_project?' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    context 'when project is nil' do
      it 'returns false' do
        expect(described_class.duo_agent_platform_available_for_project?(nil)).to be false
      end
    end

    context 'when duo_agent_platform is not available' do
      before do
        allow(described_class).to receive(:duo_agent_platform_available?).with(project).and_return(false)
      end

      it 'returns false' do
        expect(described_class.duo_agent_platform_available_for_project?(project)).to be false
      end
    end

    context 'when duo_agent_platform is available' do
      before do
        allow(described_class).to receive(:duo_agent_platform_available?).with(project).and_return(true)
      end

      context 'when project has duo_features_enabled set to false' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        it 'returns false' do
          expect(described_class.duo_agent_platform_available_for_project?(project)).to be false
        end
      end

      context 'when project has duo_features_enabled set to true' do
        before do
          project.project_setting.update!(duo_features_enabled: true)
        end

        it 'returns true' do
          expect(described_class.duo_agent_platform_available_for_project?(project)).to be true
        end
      end
    end
  end

  describe '.duo_features_enabled_for_self_or_descendants?' do
    let_it_be_with_reload(:group) { create(:group) }

    subject(:duo_features_enabled_for_hierarchy) do
      described_class.duo_features_enabled_for_self_or_descendants?(group)
    end

    context 'when the group itself has Duo features enabled' do
      before do
        group.namespace_settings.update!(duo_features_enabled: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when the group has Duo features disabled' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false)
      end

      context 'and no descendant has Duo features enabled' do
        it { is_expected.to be(false) }
      end

      context 'and a descendant subgroup has Duo features enabled' do
        let(:subgroup) { create(:group, parent: group) }

        before do
          subgroup.namespace_settings.update!(duo_features_enabled: true)
        end

        it { is_expected.to be(true) }
      end

      context 'and a descendant project has Duo features enabled' do
        let_it_be(:project) { create(:project, group: group) }

        before do
          project.project_setting.update!(duo_features_enabled: true)
        end

        it { is_expected.to be(true) }
      end

      context 'and a deeply nested descendant subgroup has Duo features enabled' do
        let(:subgroup) { create(:group, parent: group) }
        let(:nested_subgroup) { create(:group, parent: subgroup) }

        before do
          subgroup.namespace_settings.update!(duo_features_enabled: false)
          nested_subgroup.namespace_settings.update!(duo_features_enabled: true)
        end

        it { is_expected.to be(true) }
      end

      context 'and a deeply nested descendant project has Duo features enabled' do
        let_it_be_with_reload(:subgroup) { create(:group, parent: group) }
        let_it_be(:nested_project) { create(:project, group: subgroup) }

        before do
          subgroup.namespace_settings.update!(duo_features_enabled: false)
          nested_project.project_setting.update!(duo_features_enabled: true)
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#ensure_service_account_unblocked!' do
    let_it_be(:current_user) { create(:user, :admin) }
    let_it_be_with_reload(:blocked_service_account) { create(:user, :service_account, :blocked) }

    context 'with service_account set in application settings' do
      where(:service_account, :expected_service_class, :expected_status, :expected_message) do
        ref(:service_account_user) | nil | true | "Service account already unblocked. Nothing to do."
        ref(:blocked_service_account) | ::Users::UnblockService | true | nil
      end

      with_them do
        before do
          Ai::Setting.for_organization(current_org).update!(duo_workflow_service_account_user_id: service_account&.id)
        end

        it 'conditionally block the service account', :aggregate_failures do
          if expected_service_class
            expect_next_instance_of(expected_service_class, current_user) do |instance|
              expect(instance).to receive(:execute).with(service_account).and_call_original
            end
          end

          response = described_class.ensure_service_account_unblocked!(current_user: current_user)

          expect(response.success?).to be(expected_status)
          expect(response.message).to be(expected_message)
        end
      end
    end

    context 'with service_account set as argument' do
      it 'conditionally blocks the given service account', :aggregate_failures do
        expect(blocked_service_account.blocked?).to be(true)

        response = described_class.ensure_service_account_unblocked!(
          current_user: current_user,
          service_account: blocked_service_account
        )

        expect(response.success?).to be(true)
        expect(blocked_service_account.blocked?).to be(false)
      end
    end
  end
end
