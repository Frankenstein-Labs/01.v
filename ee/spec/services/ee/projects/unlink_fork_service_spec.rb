# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UnlinkForkService, :use_clean_rails_memory_store_caching, feature_category: :groups_and_projects do
  include ProjectForksHelper

  subject(:service) { described_class.new(forked_project, user) }

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user) }

  before do
    stub_ee_application_setting(elasticsearch_indexing?: true)
  end

  context 'when forked project is unlinked from parent' do
    let!(:forked_project) { fork_project(project, user) }

    it 'creates an audit event', :aggregate_failures do
      expect(::Gitlab::Audit::Auditor)
            .to receive(:audit).with(
              hash_including({ name: "project_fork_relationship_removed" })).and_call_original

      expect { service.execute }.to change { AuditEventReader.count }.by(1)

      expect(AuditEventReader.last).to have_attributes({
        author: user,
        entity_id: forked_project.id,
        target_type: project.class.name,
        details: {
          author_class: user.class.name,
          author_name: user.name,
          custom_message: "Project unlinked from #{project.name}",
          event_name: 'project_fork_relationship_removed',
          target_details: forked_project.name,
          target_id: forked_project.id,
          target_type: forked_project.class.name
        }
      })
    end

    it 'calls process bookeeping service' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(forked_project).once
      service.execute
    end

    it 'creates an audit when project statistics are not refreshed' do
      expect { service.execute(refresh_statistics: false) }.to change { AuditEventReader.count }.by(1)
    end

    context 'when forked project does not exist' do
      before do
        project.destroy!
      end

      it 'creates an audit event', :aggregate_failures do
        expect(::Gitlab::Audit::Auditor)
          .to receive(:audit).with(
            hash_including({ name: "project_fork_relationship_removed" })).and_call_original

        expect { service.execute }.to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last).to have_attributes({
          author: user,
          entity_id: forked_project.id,
          target_type: project.class.name,
          details: {
            author_class: user.class.name,
            author_name: user.name,
            custom_message: "Project unlinked from ",
            event_name: 'project_fork_relationship_removed',
            target_details: forked_project.name,
            target_id: forked_project.id,
            target_type: forked_project.class.name
          }
        })
      end
    end
  end

  context 'when no unlinking is performed' do
    let(:forked_project) { project }

    it 'does not create an audit event' do
      expect { service.execute }.not_to change { AuditEventReader.count }
    end

    it 'does not call process bookeeping service' do
      service.execute
      expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
    end
  end
end
