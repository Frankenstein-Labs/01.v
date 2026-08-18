# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NotificationRecipients::Builder::ServiceAccount, feature_category: :user_management do
  describe '#notification_recipients' do
    let(:service_account) { create(:user, :service_account) }
    let(:pipeline) { create(:ci_pipeline, user: service_account) }
    let(:user) { create(:user, developer_of: pipeline.project) }
    let(:pipeline_status) { pipeline.status }

    subject(:build_service_method) do
      ::NotificationRecipients::Builder::ServiceAccount
        .new(pipeline.project, pipeline.user, pipeline_status).notification_recipients.map(&:user)
    end

    context 'when no user subscribed for service account notifications' do
      it 'returns empty array' do
        expect(build_service_method).to be_empty
      end
    end

    context 'when there is one subscriber' do
      let(:notification_setting) { user.notification_settings_for(pipeline.project) }

      before do
        notification_setting.update!(level: "custom")
      end

      context 'with no settings set' do
        it 'returns empty array' do
          expect(build_service_method).to be_empty
        end
      end

      context 'with service_account_failed_pipeline notification setting checked and pipeline failed' do
        before do
          notification_setting.update!(service_account_failed_pipeline: "true")
          pipeline.drop!
        end

        it 'returns an array with the subscribed user' do
          expect(build_service_method).to match_array([user])
        end
      end

      context 'with service_account_failed_pipeline notification setting checked and pipeline succeeded' do
        before do
          notification_setting.update!(service_account_failed_pipeline: "true")
          pipeline.succeed!
        end

        it 'returns empty array' do
          expect(build_service_method).to be_empty
        end
      end

      context 'with service_account_success_pipeline notification setting checked and pipeline succeeded' do
        before do
          notification_setting.update!(service_account_success_pipeline: "true")
          pipeline.succeed!
        end

        it 'returns an array with the subscribed user' do
          expect(build_service_method).to match_array([user])
        end
      end

      context 'with service_account_fixed_pipeline notification setting checked and pipeline fixed' do
        let(:pipeline_status) { "fixed" }

        before do
          notification_setting.update!(service_account_fixed_pipeline: "true")
        end

        it 'returns an array with the subscribed user' do
          expect(build_service_method).to match_array([user])
        end
      end
    end
  end
end
