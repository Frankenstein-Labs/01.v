# frozen_string_literal: true

require "spec_helper"

RSpec.describe Projects::DisableLegacyInactiveProjectsService, feature_category: :groups_and_projects do
  describe '#perform' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:inactive_timestamp) { described_class::INACTIVE_PERIOD.ago - 1.day }
    let_it_be(:active_private_project) { create_legacy_license_project(Gitlab::VisibilityLevel::PRIVATE, 1.day.ago) }
    let_it_be(:active_public_project) { create_legacy_license_project(Gitlab::VisibilityLevel::PUBLIC, 1.day.ago) }
    let_it_be(:inactive_private_project) do
      create_legacy_license_project(Gitlab::VisibilityLevel::PRIVATE, inactive_timestamp)
    end

    let_it_be(:inactive_public_projects) do
      Array.new(4) { create_legacy_license_project(Gitlab::VisibilityLevel::PUBLIC, inactive_timestamp) }
    end

    before do
      stub_const("#{described_class}::UPDATE_BATCH_SIZE", 1)
      stub_const("#{described_class}::PAUSE_SECONDS", 0)
    end

    context 'when the combined batch size is more than or equal to the inactive public projects count' do
      before do
        stub_const("#{described_class}::LOOP_LIMIT", inactive_public_projects.size)
      end

      it 'disables legacy open-source license for all the public projects' do
        subject.execute

        expect(inactive_public_projects.map { |project| updated_license(project) }).to all(be false)
        expect(updated_license(active_public_project)).to be(true)
        expect(updated_license(inactive_private_project)).to be(true)
        expect(updated_license(active_private_project)).to be(true)
      end
    end

    context 'when the combined batch size is less than the inactive public projects count' do
      before do
        stub_const("#{described_class}::LOOP_LIMIT", 1)
      end

      it 'terminates the worker before completing all the projects' do
        subject.execute

        migrated_projects_count = described_class::LOOP_LIMIT
        unmigrated_projects_count = inactive_public_projects.size - described_class::LOOP_LIMIT

        all_licenses = inactive_public_projects
          .map { |inactive_public_project| updated_license(inactive_public_project) }

        expect(all_licenses.count(false)).to eq(migrated_projects_count)
        expect(all_licenses.count(true)).to eq(unmigrated_projects_count)
      end
    end
  end

  def updated_license(project)
    project.project_setting.reload.legacy_open_source_license_available
  end

  def create_legacy_license_project(visibility_level, last_activity_at)
    create(:project, visibility_level: visibility_level).tap do |project|
      project.update!(last_activity_at: last_activity_at)
      create(:project_setting, project: project, legacy_open_source_license_available: true)
    end
  end
end
