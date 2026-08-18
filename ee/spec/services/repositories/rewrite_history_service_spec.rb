# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repositories::RewriteHistoryService, feature_category: :source_code_management do
  subject(:service) { described_class.new(project, user) }

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  describe '#execute', :aggregate_failures do
    subject(:execute) { service.execute(blob_oids: blob_oids, redactions: redactions) }

    let(:blob_oids) { [] }
    let(:redactions) { [] }

    before do
      allow_next_instance_of(Gitlab::GitalyClient::CleanupService) do |instance|
        allow(instance).to receive(:rewrite_history)
      end
    end

    describe 'blobs removal' do
      let(:blob_oids) { ['53855584db773c3df5b5f61f72974cb298822fbb'] }

      context 'when audit events are licensed' do
        before do
          stub_licensed_features(audit_events: true)
        end

        it 'creates an audit event' do
          expect { execute }.to change { AuditEventReader.count }.from(0).to(1)
          expect(AuditEventReader.first.attributes.deep_symbolize_keys).to match a_hash_including(
            author_id: user.id,
            project_id: project.id,
            target_id: project.id,
            details: a_hash_including(custom_message: 'Project blobs removed'))
        end
      end

      context 'when audit events are not licensed' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it 'does not audit the change' do
          expect { execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    describe 'text redaction' do
      let(:redactions) { ['pass'] }

      context 'when audit events are licensed' do
        before do
          stub_licensed_features(audit_events: true)
        end

        it 'audits the changes' do
          expect { execute }.to change { AuditEventReader.count }.from(0).to(1)
          expect(AuditEventReader.first.attributes.deep_symbolize_keys).to match a_hash_including(
            author_id: user.id,
            project_id: project.id,
            target_id: project.id,
            details: a_hash_including(custom_message: 'Project text replaced'))
        end
      end

      context 'when audit events are not licensed' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it 'does not audit the change' do
          expect { execute }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
