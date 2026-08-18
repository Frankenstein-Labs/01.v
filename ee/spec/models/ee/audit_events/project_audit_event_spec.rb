# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::AuditEvents::ProjectAuditEvent, feature_category: :audit_events do
  let_it_be(:project_audit_event) { create(:audit_events_project_audit_event) }

  describe '#entity' do
    it 'returns project' do
      expect(project_audit_event.entity).to eq(project_audit_event.project)
    end
  end

  describe '#present' do
    it 'returns a presenter' do
      expect(project_audit_event.present).to be_an_instance_of(AuditEventPresenter)
    end
  end

  describe '#root_group_entity' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:project) { create(:project, group: root_group) }

    context 'when root_group_entity_id is set' do
      subject(:event) { described_class.new(root_group_entity_id: root_group.id) }

      it "return root_group_entity through root_group_entity_id" do
        expect(event.root_group_entity).to eq(root_group)
      end
    end

    context "when project is nil" do
      subject(:event) { described_class.new(project: nil) }

      it "return nil" do
        expect(event.root_group_entity).to be_nil
      end
    end

    subject(:event) { described_class.new(project: project) }

    it "return root_group and set root_group_entity_id" do
      expect(event.root_group_entity).to eq(root_group)
      expect(event.root_group_entity_id).to eq(root_group.id)
    end
  end

  describe 'streamable_namespace' do
    it 'returns project namespace' do
      expect(project_audit_event.streamable_namespace).to eq(project_audit_event.project.project_namespace)
    end
  end

  it_behaves_like 'streaming audit event model'
end
