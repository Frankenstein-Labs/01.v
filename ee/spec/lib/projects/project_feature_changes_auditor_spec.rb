# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProjectFeatureChangesAuditor, feature_category: :groups_and_projects do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, owners: user) }
    let_it_be(:project, freeze: false) { create(:project, :pages_enabled, group: group, visibility_level: 0) }
    let(:features) { project.project_feature }
    let(:project_feature_changes_auditor) { described_class.new(user, features, project) }

    before_all do
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    before do
      stub_licensed_features(extended_audit_events: true, audit_events: true, external_audit_events: true)
    end

    it 'creates an event when any project feature level changes', :aggregate_failures do
      columns = project.project_feature.attributes.keys.select { |attr| attr.end_with?('level') }
      columns.each do |column|
        event_name = "project_feature_#{column}_updated"
        previous_value = features.method(column).call
        new_value = if previous_value == ProjectFeature::DISABLED
                      ProjectFeature::ENABLED
                    else
                      ProjectFeature::DISABLED
                    end

        features.update_attribute(column, new_value)

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
          .with(event_name, anything, anything)

        expect { project_feature_changes_auditor.execute }.to change { AuditEventReader.count }.by(1)

        event = AuditEventReader.last
        expect(event.details[:from]).to eq ProjectFeature.str_from_access_level(previous_value)
        expect(event.details[:to]).to eq ProjectFeature.str_from_access_level(new_value)
        expect(event.details[:change]).to eq described_class::COLUMNS_HUMAN_NAME.fetch(column).to_s
      end
    end

    it 'audits ProjectFeature::PUBLIC levels' do
      column = 'pages_access_level'
      event_name = "project_feature_#{column}_updated"
      previous_value = features.method(column).call
      new_value = ProjectFeature::PUBLIC

      features.update_attribute(column, new_value)

      expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
        .with(event_name, anything, anything)

      expect { project_feature_changes_auditor.execute }.to change { AuditEventReader.count }.by(1)

      event = AuditEventReader.last
      expect(event.details[:from]).to eq ProjectFeature.str_from_access_level(previous_value)
      expect(event.details[:to]).to eq 'public'
      expect(event.details[:change]).to eq 'pages'
    end

    it 'audits ProjectFeature::PRIVATE levels' do
      column = 'merge_requests_access_level'
      event_name = "project_feature_#{column}_updated"
      previous_value = features.method(column).call
      new_value = ProjectFeature::PRIVATE

      features.update_attribute(column, new_value)

      expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
        .with(event_name, anything, anything)

      expect { project_feature_changes_auditor.execute }.to change { AuditEventReader.count }.by(1)

      event = AuditEventReader.last
      expect(event.details[:from]).to eq ProjectFeature.str_from_access_level(previous_value)
      expect(event.details[:to]).to eq 'private'
      expect(event.details[:change]).to eq 'merge requests'
    end
  end
end
