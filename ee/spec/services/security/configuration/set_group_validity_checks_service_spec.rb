# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetGroupValidityChecksService, feature_category: :security_testing_configuration do
  describe '#execute' do
    let_it_be(:user) { create(:user) }

    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:mid_level_group) { create(:group, parent: top_level_group) }
    let_it_be(:bottom_level_group) { create(:group, parent: mid_level_group) }

    let_it_be_with_reload(:top_level_group_project) { create(:project, namespace: top_level_group) }
    let_it_be_with_reload(:mid_level_group_project) { create(:project, namespace: mid_level_group) }
    let_it_be_with_reload(:bottom_level_group_project) { create(:project, namespace: bottom_level_group) }
    let_it_be_with_reload(:excluded_project) { create(:project, namespace: mid_level_group) }

    let(:projects_to_change) { [top_level_group_project, mid_level_group_project, bottom_level_group_project] }

    def execute_service(subject:, enable: true, excluded_projects_ids: [excluded_project.id])
      described_class
        .new(subject: subject, enable: enable, current_user: user, excluded_projects_ids: excluded_projects_ids)
        .execute
    end

    it 'changes the attribute for nested projects' do
      boolean_values = [true, false]

      projects_to_change.each do |project|
        security_setting = project.security_setting

        boolean_values.each do |enable_value|
          expect { execute_service(subject: top_level_group, enable: enable_value) }.to change {
            security_setting.reload.validity_checks_enabled
          }.from(!enable_value).to(enable_value)

          expect { execute_service(subject: top_level_group, enable: enable_value) }
            .not_to change { security_setting.reload.validity_checks_enabled }
        end
      end
    end

    it 'changes updated_at timestamp' do
      expect { execute_service(subject: top_level_group) }.to change {
        mid_level_group_project.reload.security_setting.updated_at
      }
    end

    it 'doesnt change the attribute for projects in excluded list' do
      security_setting = excluded_project.security_setting
      expect { execute_service(subject: top_level_group) }.not_to change {
        security_setting.reload.validity_checks_enabled
      }

      expect { execute_service(subject: mid_level_group, enable: false) }.not_to change {
        security_setting.reload.validity_checks_enabled
      }
    end

    it 'rolls back changes when an error occurs' do
      initial_values = projects_to_change.map do |project|
        project.security_setting.validity_checks_enabled
      end

      call_counter = 0
      # Simulate an error on the last call to `update_security_setting` to make sure some changes were already made
      allow(described_class).to receive(:update_security_setting) do |projects, enable, excluded_projects_ids|
        call_counter += 1
        raise StandardError, "Simulated error on the third project" if call_counter == (projects_to_change.length - 1)

        described_class.send(:super, projects, enable, excluded_projects_ids)
      end

      expect do
        described_class.execute(subject: top_level_group, enable: true,
          excluded_projects_ids: [excluded_project.id])
      end.to raise_error(StandardError)

      projects_to_change.each_with_index do |project, index|
        project.reload
        expect(project.security_setting.validity_checks_enabled).to eq(initial_values[index])
      end
    end

    describe 'auditing' do
      context 'when no excluded projects ids are provided' do
        it 'audits using the correct properties' do
          expect { execute_service(subject: top_level_group, excluded_projects_ids: []) }
            .to change { AuditEventReader.count }.by(1)
          expect(AuditEventReader.last.details[:custom_message]).to eq(
            "Validity checks has been enabled for group #{top_level_group.name} and all of its inherited \
groups/projects")
          expect(AuditEventReader.last.details[:author_name]).to eq(user.name)
          expect(AuditEventReader.last.details[:event_name]).to eq("group_validity_checks_updated")
          expect(AuditEventReader.last.details[:target_details]).to eq(top_level_group.name)

          expect { execute_service(subject: top_level_group, excluded_projects_ids: [], enable: false) }
            .to change { AuditEventReader.count }.by(1)
          expect(AuditEventReader.last.details[:custom_message]).to eq(
            "Validity checks has been disabled for group #{top_level_group.name} and all of its inherited \
groups/projects")
        end
      end

      context 'when excluded projects ids are provided' do
        context 'when excluded ids matches projects in that group' do
          it 'audits using the correct properties' do
            expect { execute_service(subject: top_level_group) }.to change { AuditEventReader.count }.by(1)
            expect(AuditEventReader.last.details[:custom_message]).to eq(
              "Validity checks has been enabled for group #{top_level_group.name} and all of its inherited \
groups/projects except for #{excluded_project.full_path}")
            expect(AuditEventReader.last.details[:author_name]).to eq(user.name)
            expect(AuditEventReader.last.details[:event_name]).to eq("group_validity_checks_updated")
            expect(AuditEventReader.last.details[:target_details]).to eq(top_level_group.name)
          end
        end

        context 'when excluded ids does not match projects in that group' do
          it 'audits using the correct properties' do
            expect do
              execute_service(subject: top_level_group, excluded_projects_ids: [Time.now.to_i])
            end.to change { AuditEventReader.count }.by(1)
            expect(AuditEventReader.last.details[:custom_message]).to eq(
              "Validity checks has been enabled for group #{top_level_group.name} and all of its inherited \
groups/projects")
            expect(AuditEventReader.last.details[:author_name]).to eq(user.name)
            expect(AuditEventReader.last.details[:event_name]).to eq("group_validity_checks_updated")
            expect(AuditEventReader.last.details[:target_details]).to eq(top_level_group.name)
          end
        end
      end
    end

    context 'when security_setting record does not yet exist' do
      before do
        bottom_level_group_project.security_setting.destroy!
      end

      it 'creates security_setting and sets the value appropriately' do
        expect { execute_service(subject: bottom_level_group) }.to change {
          bottom_level_group_project.reload.security_setting
        }.from(nil).to(be_a(ProjectSecuritySetting))

        expect(bottom_level_group_project.reload.security_setting.validity_checks_enabled)
          .to be(true)
        expect(AuditEventReader.last.details[:custom_message]).to eq(
          "Validity checks has been enabled for group #{bottom_level_group.name} and all of its inherited \
groups/projects")
        expect(AuditEventReader.last.details[:target_id]).to eq(bottom_level_group.id)
      end
    end

    context 'when arguments are invalid' do
      it 'does not change the attribute' do
        expect { execute_service(subject: top_level_group, enable: nil) }
          .not_to change { top_level_group_project.reload.security_setting.validity_checks_enabled }
      end
    end
  end
end
