# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetValidityChecksService, feature_category: :secret_detection do
  describe '#execute' do
    let_it_be(:security_setting) { create(:project_security_setting, validity_checks_enabled: false) }
    let_it_be(:current_user) { create(:user, :admin) }
    let_it_be(:project) { security_setting.project }

    it 'returns attribute value' do
      expect(described_class.execute(current_user: current_user, project: project,
        enable: true)).to have_attributes(errors: be_blank, payload: include(enabled: true))
      expect(described_class.execute(current_user: current_user, project: project,
        enable: false)).to have_attributes(errors: be_blank, payload: include(enabled: false))
    end

    it 'changes the attribute' do
      expect { described_class.execute(current_user: current_user, project: project, enable: true) }
        .to change { security_setting.reload.validity_checks_enabled }
        .from(false).to(true)
      expect { described_class.execute(current_user: current_user, project: project, enable: true) }
        .not_to change { security_setting.reload.validity_checks_enabled }
      expect { described_class.execute(current_user: current_user, project: project, enable: false) }
        .to change { security_setting.reload.validity_checks_enabled }
        .from(true).to(false)
      expect { described_class.execute(current_user: current_user, project: project, enable: false) }
        .not_to change { security_setting.reload.validity_checks_enabled }
    end

    context 'when security_setting record does not yet exist' do
      let_it_be(:project_without_security_setting) { create(:project) }

      before do
        project_without_security_setting.security_setting.delete
      end

      it 'creates the necessary record and updates the record appropriately' do
        expect(described_class.execute(current_user: current_user, project: project_without_security_setting.reload,
          enable: true)).to have_attributes(errors: be_blank, payload: include(enabled: true))
      end
    end

    context 'when attribute changes from false to true' do
      it 'creates an audit event with the correct message' do
        expect { described_class.execute(current_user: current_user, project: project, enable: true) }
          .to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details[:custom_message]).to eq(
          "Validity checks has been enabled")
      end
    end

    context 'when attribute changes from true to false' do
      let(:security_setting2) { create(:project_security_setting, validity_checks_enabled: true) }
      let(:project2) { security_setting2.project }

      it 'creates an audit event with the correct message' do
        expect { described_class.execute(current_user: current_user, project: project2, enable: false) }
          .to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details[:custom_message]).to eq(
          "Validity checks has been disabled")
      end
    end

    context 'when fields are invalid' do
      it 'returns nil and error' do
        expect(described_class.execute(current_user: current_user, project: project,
          enable: nil)).to have_attributes(errors: be_present, payload: include(enabled: nil))
      end

      it 'does not change the attribute' do
        expect { described_class.execute(current_user: current_user, project: project, enable: nil) }
          .not_to change { security_setting.reload.validity_checks_enabled }
      end
    end
  end
end
