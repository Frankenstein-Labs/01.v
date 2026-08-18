# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetProjectSecuritySettingBaseService, feature_category: :security_testing_configuration do
  let_it_be(:user) { create(:user) }
  let_it_be(:project_1) { create(:project) }
  let(:service) do
    described_class.new(subject: project_1, enable: true, current_user: user)
  end

  describe '#execute' do
    context 'when the call is valid' do
      it 'executes the transaction and returns the enable value' do
        allow(service).to receive_messages(valid_request?: true, subject_project_ids: [project_1.id],
          audit: nil, setting_key: :secret_push_protection_enabled)

        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker)
          .not_to receive(:perform_async)

        expect { service.execute }.to change {
          project_1.security_setting.reload.secret_push_protection_enabled
        }.from(false).to(true)
        expect(service.execute).to be(true)
      end
    end

    context 'when the call is invalid' do
      it 'does nothing and returns nil' do
        allow(service).to receive_messages(valid_request?: false, subject_project_ids: [project_1.id],
          audit: nil, setting_key: :secret_push_protection_enabled)

        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker)
          .not_to receive(:perform_async)

        expect { service.execute }.not_to change {
          project_1.security_setting.reload.secret_push_protection_enabled
        }
        expect(service.execute).to be_nil
      end
    end
  end

  describe '#post_update' do
    it 'is a no-op by default in the base service' do
      expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker)
        .not_to receive(:perform_async)

      service.send(:post_update, [project_1.id])
    end
  end

  describe '#audit' do
    it 'requires a subclass overrides it' do
      expect { service.send(:audit) }.to raise_error(NotImplementedError)
    end
  end

  describe '#subject_project_ids' do
    it 'requires a subclass overrides it' do
      expect { service.send(:subject_project_ids) }.to raise_error(NotImplementedError)
    end
  end

  describe '#setting_key' do
    it 'requires a subclass overrides it' do
      expect { service.send(:setting_key) }.to raise_error(NotImplementedError)
    end
  end
end
