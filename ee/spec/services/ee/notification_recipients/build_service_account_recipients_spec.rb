# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::NotificationRecipients::BuildService, feature_category: :team_planning do
  let(:service) { described_class }

  describe '#build_service_account_recipients' do
    let(:service_account) { create(:user, :service_account) }
    let(:pipeline) { create(:ci_pipeline, user: service_account) }
    let(:user) { create(:user, developer_of: pipeline.project) }
    let(:pipeline_status) { pipeline.status }

    context 'when no user subscribed for service account notifications' do
      it 'does not add recipient' do
        recipients = service.build_service_account_recipients(pipeline.project, pipeline.user, pipeline_status)
        expect(recipients).to be_empty
      end
    end

    context 'when there is one subscriber' do
      let(:notification_setting) { user.notification_settings_for(pipeline.project) }

      before do
        notification_setting.update!(level: "custom")
      end

      context 'with no settings set' do
        it 'does not add recipient' do
          recipients = service.build_service_account_recipients(pipeline.project, pipeline.user, pipeline_status)
          expect(recipients).to be_empty
        end
      end

      context 'with service_account_failed_pipeline notification setting checked and pipeline failed' do
        before do
          notification_setting.update!(service_account_failed_pipeline: "true")
          pipeline.drop!
        end

        it 'adds subscribed user to recipients' do
          recipients = service.build_service_account_recipients(pipeline.project, pipeline.user, pipeline_status)
          expect(recipients).to match_array([user])
        end
      end
    end
  end
end
