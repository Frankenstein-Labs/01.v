# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetProjectValidityChecksService, feature_category: :secret_detection do
  describe '#execute' do
    let_it_be(:user) { create(:user) }

    let_it_be_with_reload(:project_1) { create(:project) }
    let_it_be_with_reload(:project_2) { create(:project) }
    let_it_be_with_reload(:excluded_project) { create(:project) }

    def execute_service(subject:, enable: true, excluded_projects_ids: [excluded_project.id])
      described_class
        .new(subject: subject, enable: enable, current_user: user, excluded_projects_ids: excluded_projects_ids)
        .execute
    end

    it 'changes the attribute' do
      security_setting = project_2.security_setting
      expect { execute_service(subject: project_2) }.to change {
        security_setting.reload.validity_checks_enabled
      }.from(false).to(true)

      expect { execute_service(subject: project_2) }.not_to change {
        security_setting.reload.validity_checks_enabled
      }

      expect { execute_service(subject: project_2, enable: false) }.to change {
        security_setting.reload.validity_checks_enabled
      }.from(true).to(false)

      expect { execute_service(subject: project_2, enable: false) }.not_to change {
        security_setting.reload.validity_checks_enabled
      }
    end

    it 'changes updated_at timestamp' do
      expect { execute_service(subject: project_1) }
        .to change { project_1.reload.security_setting.updated_at }
    end

    describe 'auditing' do
      context 'when no excluded_projects ids are provided' do
        it 'audits using the correct properties' do
          expect { execute_service(subject: project_2) }.to change { AuditEventReader.count }.by(1)
          expect(AuditEventReader.last.details[:custom_message]).to eq("Validity checks has been enabled")

          expect { execute_service(subject: project_2, enable: false) }.to change {
            AuditEventReader.count
          }.by(1)
          expect(AuditEventReader.last.details[:custom_message]).to eq("Validity checks has been disabled")
          expect(AuditEventReader.last.details[:author_name]).to eq(user.name)
          expect(AuditEventReader.last.details[:event_name]).to eq("project_security_setting_updated")
          expect(AuditEventReader.last.details[:target_details]).to eq(project_2.name)
        end

        it 'doesnt create audit if no change was made' do
          expect { execute_service(subject: project_2) }.to change { AuditEventReader.count }.by(1)
          # executing again with the same value should not create audit as there is no change
          expect { execute_service(subject: project_2) }.not_to change { AuditEventReader.count }
        end
      end

      context 'when excluded_projects ids includes the project id' do
        it 'doesnt create audit' do
          expect { execute_service(subject: excluded_project) }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'when security_setting record does not yet exist' do
      let_it_be_with_reload(:project_without_security_setting) { create(:project) }

      before do
        project_without_security_setting.security_setting.destroy!
      end

      it 'creates security_setting and sets the value appropriately' do
        expect { execute_service(subject: project_without_security_setting) }
          .to change { project_without_security_setting.reload.security_setting }
                .from(nil).to(be_a(ProjectSecuritySetting))

        expect(project_without_security_setting.reload.security_setting.validity_checks_enabled)
          .to be(true)

        expect(AuditEventReader.last.details[:custom_message]).to eq("Validity checks has been enabled")
        expect(AuditEventReader.last.details[:target_id]).to eq(project_without_security_setting.id)
      end
    end

    context 'when arguments are invalid' do
      it 'does not change the attribute' do
        expect { execute_service(subject: project_2, enable: nil) }
          .not_to change { project_2.reload.security_setting.validity_checks_enabled }

        expect { execute_service(subject: project_2, enable: 'random') }
          .not_to change { project_2.reload.security_setting.validity_checks_enabled }
      end
    end
  end
end
