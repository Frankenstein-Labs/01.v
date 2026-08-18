# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Audit::Levels::Project, feature_category: :audit_events do
  describe '#apply' do
    let_it_be(:project) { create(:project) }

    let_it_be(:project_audit_event) { create(:project_audit_event, entity_id: project.id) }

    subject(:audit_events) { described_class.new(project: project).apply }

    it 'finds all project events' do
      expect(audit_events).to contain_exactly(project_audit_event)
    end
  end
end
