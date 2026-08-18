# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Registry::RepositoriesController, feature_category: :container_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:repository) { create(:container_repository, :root, project: project) }

  describe '#destroy' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      sign_in(user)

      stub_container_registry_config(enabled: true)
      stub_container_registry_info

      stub_licensed_features(external_audit_events: true)
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    subject(:destroy_repo) do
      delete :destroy, params: {
        namespace_id: project.namespace, project_id: project, id: repository
      }, format: :json
    end

    it 'creates an audit event' do
      expected_message = "Marked container repository #{repository.id} for deletion"

      expect { destroy_repo }.to change { AuditEventReader.count }.by(1)

      expect(AuditEventReader.last.details[:custom_message]).to eq(expected_message)
    end

    it_behaves_like 'sends correct event type in audit event stream' do
      let_it_be(:event_type) { 'container_repository_deletion_marked' }
    end
  end
end
