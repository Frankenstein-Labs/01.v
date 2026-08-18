# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::AuditEvents::InstanceAuditEvent, feature_category: :audit_events do
  let_it_be(:instance_audit_event) { create(:audit_events_instance_audit_event) }

  describe '#entity' do
    it 'returns an instance scope' do
      expect(instance_audit_event.entity).to be_an_instance_of(::Gitlab::Audit::InstanceScope)
    end
  end

  describe '#present' do
    it 'returns a presenter' do
      expect(instance_audit_event.present).to be_an_instance_of(AuditEventPresenter)
    end
  end

  describe '#streamable_namespace' do
    let(:audit_event) { build(:audit_events_instance_audit_event) }

    context 'when target_type or target_id is missing' do
      it 'returns nil when target_type is nil' do
        audit_event.details[:target_type] = nil
        audit_event.details[:target_id] = 1

        expect(audit_event.streamable_namespace).to be_nil
      end

      it 'returns nil when target_id is nil' do
        audit_event.details[:target_type] = 'Project'
        audit_event.details[:target_id] = nil

        expect(audit_event.streamable_namespace).to be_nil
      end

      it 'returns nil when both are nil' do
        audit_event.details[:target_type] = nil
        audit_event.details[:target_id] = nil

        expect(audit_event.streamable_namespace).to be_nil
      end
    end

    context 'when target_type is Project' do
      let(:project) { create(:project) }

      before do
        audit_event.target_type = 'Project'
        audit_event.details[:target_type] = 'Project'
        audit_event.details[:target_id] = project.id
      end

      it 'returns the project namespace' do
        expect(audit_event.streamable_namespace).to eq(project.project_namespace)
      end

      it 'returns nil when project does not exist' do
        audit_event.details[:target_id] = non_existing_record_id

        expect(audit_event.streamable_namespace).to be_nil
      end
    end

    context 'when target_type is Group' do
      let(:group) { create(:group) }

      before do
        audit_event.target_type = 'Group'
        audit_event.details[:target_type] = 'Group'
        audit_event.details[:target_id] = group.id
      end

      it 'returns the group when it exists' do
        expect(audit_event.streamable_namespace).to eq(group)
      end

      it 'returns nil when group does not exist' do
        audit_event.details[:target_id] = non_existing_record_id

        expect(audit_event.streamable_namespace).to be_nil
      end
    end

    context 'when target_type is Namespaces::ProjectNamespace' do
      let(:project) { create(:project) }
      let(:project_namespace) { project.project_namespace }

      before do
        audit_event.target_type = 'Namespaces::ProjectNamespace'
        audit_event.details[:target_type] = 'Namespaces::ProjectNamespace'
        audit_event.details[:target_id] = project_namespace.id
      end

      it 'returns the project namespace when it exists' do
        expect(audit_event.streamable_namespace).to eq(project_namespace)
      end

      it 'returns nil when project namespace does not exist' do
        audit_event.details[:target_id] = non_existing_record_id

        expect(audit_event.streamable_namespace).to be_nil
      end
    end

    context 'when target_type is unknown' do
      it 'returns nil for unsupported target_type' do
        audit_event.target_type = 'UnknownType'
        audit_event.details[:target_type] = 'UnknownType'
        audit_event.details[:target_id] = 1

        expect(audit_event.streamable_namespace).to be_nil
      end
    end
  end

  it_behaves_like 'streaming audit event model'
end
