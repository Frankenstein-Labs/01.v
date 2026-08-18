# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Releases::DestroyService, feature_category: :release_orchestration do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository, maintainers: user) }
  let(:tag) { 'v1.1.0' }
  let!(:release) { create(:release, project: project, tag: tag) }
  let(:service) { described_class.new(project, user, params) }
  let(:params) { { tag: tag } }

  describe 'audit events' do
    include_examples 'audit event logging' do
      let(:operation) { service.execute }
      let(:event_type) { 'release_deleted_audit_event' }
      let(:licensed_features_to_stub) { { group_milestone_project_releases: true } }
      # rubocop:disable RSpec/AnyInstanceOf -- It's not the next instance
      let(:fail_condition!) { allow_any_instance_of(Release).to receive(:destroy).and_return(false) }
      # rubocop:enable RSpec/AnyInstanceOf

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: project.id,
          entity_type: 'Project',
          details: {
            author_name: user.name,
            author_class: 'User',
            event_name: 'release_deleted_audit_event',
            target_id: release.id,
            target_type: 'Release',
            target_details: release.name,
            custom_message: "Deleted release #{release.name}"
          }
        }
      end
    end
  end
end
