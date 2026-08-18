# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::UpdateService, feature_category: :ai_agents do
  let_it_be(:organization) { create(:common_organization) }

  before do
    stub_current_organization(organization)
  end

  describe '#execute' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
    let_it_be(:user) { create(:admin) }
    let_it_be_with_reload(:service_account) { create(:service_account) }
    let_it_be(:integration) { create(:amazon_q_integration) }

    let_it_be(:project_integration) do
      create(:amazon_q_integration, instance: false, project: create(:project), inherit_from_id: integration.id)
    end

    let_it_be(:group_integration) do
      create(:amazon_q_integration, instance: false, group: create(:group), inherit_from_id: integration.id)
    end

    let(:params) { { availability: 'default_on', auto_review_enabled: true } }
    let(:status) { 200 }
    let(:body) { 'success' }

    subject(:instance) { described_class.new(user, params) }

    before do
      stub_licensed_features(amazon_q: true)
      Ai::Setting.for_organization(organization).update!(amazon_q_service_account_user_id: service_account.id)
      ::Gitlab::CurrentSettings.current_application_settings.update!(duo_availability: 'default_off')
    end

    context 'with missing availability param' do
      let(:params) { {} }

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Missing availability parameter'
        )
      end
    end

    context 'with invalid availability param' do
      let(:params) { { availability: 'z' } }

      it 'does not change duo_availability' do
        expect { instance.execute }
          .not_to change { ::Gitlab::CurrentSettings.current_application_settings.duo_availability }
      end

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: "availability must be one of: default_on, default_off, never_on"
        )
      end
    end

    context 'when the application settings update fails' do
      let(:app_settings) { ::Gitlab::CurrentSettings.current_application_settings }
      let(:error_msg) { 'Failed to update application settings' }
      let(:error_double) { instance_double(ActiveModel::Errors, full_messages: [error_msg]) }

      before do
        # This is the critical part - explicitly mock update_settings to return false

        # Mock the application_settings method to return our app_settings with errors
        allow(instance).to receive_messages(update_settings: false, application_settings: app_settings)
        allow(app_settings).to receive(:errors).and_return(error_double)
      end

      it 'returns ServiceResponse.error with expected error message' do
        result = instance.execute

        expect(result).to have_attributes(
          success?: false,
          message: error_msg
        )
      end
    end

    context 'when settings update succeeds' do
      it 'updates application settings and returns success response' do
        expect { instance.execute }
          .to change {
            ::Gitlab::CurrentSettings.current_application_settings.duo_availability
          }.from(:default_off).to(:default_on)

        result = instance.execute
        expect(result).to be_a(ServiceResponse)
        expect(result.success?).to be(true)
      end

      it 'creates an audit event' do
        expect(instance).to receive(:create_audit_event).with(audit_availability: true, audit_ai_settings: false)

        instance.execute
      end

      context 'when setting availability to never_on' do
        let(:params) { { availability: 'never_on' } }

        it 'blocks service account' do
          expect(Ai::AmazonQ).to receive(:should_block_service_account?)
            .with(availability: 'never_on')
            .and_return(true)
          expect(Ai::AmazonQ).to receive(:ensure_service_account_blocked!)
            .with(current_user: user)
            .and_return(ServiceResponse.success)

          result = instance.execute
          expect(result).to be_success
        end

        context 'when blocking fails' do
          it 'returns the error from blocking' do
            expect(Ai::AmazonQ).to receive(:should_block_service_account?)
              .with(availability: 'never_on')
              .and_return(true)
            expect(Ai::AmazonQ).to receive(:ensure_service_account_blocked!)
              .with(current_user: user)
              .and_return(ServiceResponse.error(message: 'Failed to block'))

            result = instance.execute
            expect(result).to be_error
            expect(result.message).to eq('Failed to block')
          end
        end
      end

      context 'when service account should be unblocked' do
        it 'unblocks service account' do
          expect(Ai::AmazonQ).to receive(:should_block_service_account?)
            .with(availability: 'default_on')
            .and_return(false)
          expect(Ai::AmazonQ).to receive(:ensure_service_account_unblocked!)
            .with(current_user: user)
            .and_return(ServiceResponse.success)

          result = instance.execute
          expect(result).to be_success
        end

        context 'when unblocking fails' do
          it 'returns the error from unblocking' do
            expect(Ai::AmazonQ).to receive(:should_block_service_account?)
              .with(availability: 'default_on')
              .and_return(false)
            expect(Ai::AmazonQ).to receive(:ensure_service_account_unblocked!)
              .with(current_user: user)
              .and_return(ServiceResponse.error(message: 'Failed to unblock'))

            result = instance.execute
            expect(result).to be_error
            expect(result.message).to eq('Failed to unblock')
          end
        end
      end
    end

    context 'when testing cascading behavior' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be(:subgroup, freeze: false) { create(:group, parent: group) }
      let_it_be(:project) { create(:project, group: group) }

      before do
        # Initialize groups and projects with duo_features_enabled: true
        group.namespace_settings.update!(duo_features_enabled: true)
        subgroup.namespace_settings.update!(duo_features_enabled: true)
        project.project_setting.update!(duo_features_enabled: true)
      end

      context 'when availability is set to never_on' do
        let(:params) { { availability: 'never_on' } }

        before do
          allow(Ai::AmazonQ).to receive_messages({
            should_block_service_account?: true,
            ensure_service_account_blocked!: ServiceResponse.success
          })
        end

        it 'triggers cascading worker to update all groups and projects', :sidekiq_inline do
          instance.execute
          # the cascade worker isn't actually called when the setting is locked,
          # but values are computed correctly with the cascading settings framework
          expect(group.reload.duo_features_enabled).to be false
          expect(group.namespace_settings.duo_features_enabled_locked?).to be true
          expect(subgroup.reload.namespace_settings.duo_features_enabled).to be false
          expect(subgroup.namespace_settings.duo_features_enabled_locked?).to be true
          expect(project.reload.project_setting.duo_features_enabled).to be false
          expect(project.reload.project_setting.duo_features_enabled_locked?).to be true
        end

        it 'updates application-level duo_availability to never_on' do
          expect { instance.execute }
            .to change { ::Gitlab::CurrentSettings.current_application_settings.duo_availability }.to(:never_on)
        end
      end

      context 'when availability is set to default_on' do
        let(:params) { { availability: 'default_on' } }

        before do
          # Start with duo_availability: default_off
          ::Gitlab::CurrentSettings.current_application_settings.update!(duo_availability: 'default_off')

          allow(Ai::AmazonQ).to receive_messages({
            should_block_service_account?: false,
            ensure_service_account_unblocked!: ServiceResponse.success
          })
        end

        it 'triggers cascading worker to update all groups and projects', :sidekiq_inline do
          expect(AppConfig::CascadeDuoSettingsWorker)
            .to(receive(:perform_async))
            .with({ "duo_features_enabled" => true })

          instance.execute
        end

        it 'updates application-level duo_availability to default_on' do
          expect { instance.execute }
            .to change { ::Gitlab::CurrentSettings.current_application_settings.duo_availability }.to(:default_on)
        end
      end
    end

    it 'calls ApplicationSettings::UpdateService with correct parameters' do
      application_settings = ::Gitlab::CurrentSettings.current_application_settings
      update_service = instance_double(ApplicationSettings::UpdateService, execute: true)

      expect(ApplicationSettings::UpdateService).to receive(:new)
        .with(application_settings, user, { duo_availability: 'default_on' })
        .and_return(update_service)
      expect(update_service).to receive(:execute)

      instance.execute
    end

    it 'returns ServiceResponse.success' do
      allow(Ai::AmazonQ).to receive_messages({
        should_block_service_account?: false,
        ensure_service_account_unblocked!: ServiceResponse.success
      })

      result = instance.execute

      expect(result).to be_a(ServiceResponse)
      expect(result.success?).to be(true)
    end
  end
end
