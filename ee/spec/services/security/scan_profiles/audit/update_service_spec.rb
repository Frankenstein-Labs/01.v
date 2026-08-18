# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::Audit::UpdateService, feature_category: :security_testing_configuration do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:profile) do
    create(:security_scan_profile, :dependency_scanning_post_processing, namespace: namespace, name: 'Profile')
  end

  let(:old_snapshot) { { name: 'Profile', description: 'Old', triggers: {} } }
  let(:new_snapshot) { { name: 'Profile', description: 'Old', triggers: {} } }

  subject(:execute) do
    described_class.new(
      profile: profile,
      current_user: current_user,
      old_snapshot: old_snapshot,
      new_snapshot: new_snapshot
    ).execute
  end

  before do
    stub_licensed_features(extended_audit_events: true)
  end

  def audit_change_messages
    AuditEventReader.all.map { |event| event.details[:custom_message] }
  end

  describe '#execute' do
    context 'when nothing changed' do
      it 'does not create an audit event' do
        expect { execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when current_user is blank' do
      let(:current_user) { nil }
      let(:new_snapshot) { { name: 'Renamed', description: 'Old', triggers: {} } }

      it 'does not create an audit event' do
        expect { execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when metadata change' do
      let(:new_snapshot) { { name: 'Renamed', description: 'New', triggers: {} } }

      it 'records one event per changed attribute', :aggregate_failures do
        expect { execute }.to change { AuditEventReader.count }.by(2)

        expect(audit_change_messages).to contain_exactly(
          'Changed name from Profile to Renamed',
          'Changed description from Old to New'
        )
      end

      it 'records structured change details on each event', :aggregate_failures do
        execute

        name_event = AuditEventReader.all.find { |event| event.details[:property] == 'name' }
        expect(name_event).to have_attributes(
          entity_id: namespace.id,
          entity_type: namespace.class.name,
          target_type: 'Security::ScanProfile',
          author_id: current_user.id,
          details: hash_including(
            property: 'name', previous_value: 'Profile', new_value: 'Renamed',
            profile_id: profile.id, scan_type: profile.scan_type
          )
        )
      end
    end

    context 'when a value exceeds the audited length limit' do
      let(:long_value) { 'a' * 300 }
      let(:new_snapshot) { { name: 'Profile', description: long_value, triggers: {} } }

      it 'truncates the interpolated value in the message and details', :aggregate_failures do
        execute

        truncated = long_value.truncate(255)
        expect(AuditEventReader.last).to have_attributes(
          details: hash_including(
            property: 'description',
            new_value: truncated,
            custom_message: "Changed description from Old to #{truncated}"
          )
        )
      end
    end

    context 'when a trigger is added' do
      let(:new_snapshot) do
        { name: 'Profile', description: 'Old',
          triggers: { 'sbom_ingested' => { auto_remediation: { enabled: true }, excluded_paths: %w[a b] } } }
      end

      it 'records the trigger, its scalar config and its list config' do
        execute

        expect(audit_change_messages).to contain_exactly(
          'Set trigger sbom_ingested to enabled',
          'Set trigger sbom_ingested auto_remediation.enabled to true',
          'Added a, b to trigger sbom_ingested excluded_paths'
        )
      end
    end

    context 'when a trigger is removed' do
      let(:old_snapshot) do
        { name: 'Profile', description: 'Old',
          triggers: { 'sbom_ingested' => { auto_remediation: { enabled: true } } } }
      end

      it 'records the trigger and its configuration removal' do
        execute

        expect(audit_change_messages).to contain_exactly(
          'Removed trigger sbom_ingested (was enabled)',
          'Removed trigger sbom_ingested auto_remediation.enabled (was true)'
        )
      end
    end

    context 'when a trigger configuration key changes' do
      let(:old_snapshot) do
        { name: 'Profile', description: 'Old',
          triggers: { 'sbom_ingested' => { auto_remediation: { cooldown: 5, upgrade_policy: 'minor' } } } }
      end

      let(:new_snapshot) do
        { name: 'Profile', description: 'Old',
          triggers: { 'sbom_ingested' => { auto_remediation: { cooldown: 3, enabled: true } } } }
      end

      it 'records set/removed/changed per config key' do
        execute

        expect(audit_change_messages).to contain_exactly(
          'Changed trigger sbom_ingested auto_remediation.cooldown from 5 to 3',
          'Removed trigger sbom_ingested auto_remediation.upgrade_policy (was minor)',
          'Set trigger sbom_ingested auto_remediation.enabled to true'
        )
      end
    end

    context 'with list values' do
      let(:old_snapshot) do
        { name: 'Profile', description: 'Old',
          triggers: { 'default_branch_pipeline' => { excluded_paths: %w[a b] } } }
      end

      let(:new_snapshot) do
        { name: 'Profile', description: 'Old',
          triggers: { 'default_branch_pipeline' => { excluded_paths: %w[b c] } } }
      end

      it 'records a single event reporting the added and removed elements', :aggregate_failures do
        expect { execute }.to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last).to have_attributes(
          details: hash_including(
            custom_message: 'Added c to trigger default_branch_pipeline excluded_paths; ' \
              'Removed a from trigger default_branch_pipeline excluded_paths',
            property: 'trigger default_branch_pipeline excluded_paths',
            added: ['c'],
            removed: ['a']
          )
        )
      end

      context 'when a list changes only in order' do
        let(:new_snapshot) do
          { name: 'Profile', description: 'Old',
            triggers: { 'default_branch_pipeline' => { excluded_paths: %w[b a] } } }
        end

        it 'does not record an audit event (no set delta)' do
          expect { execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'when several kinds of change happen together' do
      let(:old_snapshot) do
        { name: 'Profile', description: 'Old', triggers: { 'sbom_ingested' => {} } }
      end

      let(:new_snapshot) do
        { name: 'Renamed', description: 'Old',
          triggers: { 'default_branch_pipeline' => { auto_remediation: { cooldown: 3 } } } }
      end

      it 'records one event per change', :aggregate_failures do
        expect { execute }.to change { AuditEventReader.count }.by(4)

        expect(audit_change_messages).to contain_exactly(
          'Changed name from Profile to Renamed',
          'Removed trigger sbom_ingested (was enabled)',
          'Set trigger default_branch_pipeline to enabled',
          'Set trigger default_branch_pipeline auto_remediation.cooldown to 3'
        )
      end
    end

    context 'when the events are rendered for display' do
      let(:old_snapshot) do
        { name: 'Profile', description: 'Old',
          triggers: { 'sbom_ingested' => { auto_remediation: { cooldown: 5, upgrade_policy: 'minor' },
                                           excluded_paths: %w[a b] } } }
      end

      let(:new_snapshot) do
        { name: 'Renamed', description: 'Old',
          triggers: { 'sbom_ingested' => { auto_remediation: { cooldown: 3, enabled: true },
                                           excluded_paths: %w[b c] } } }
      end

      it 'renders each event as the message the service generated', :aggregate_failures do
        execute

        rendered = AuditEventReader.all.map { |event| ::Audit::Details.humanize(event.details) }

        expect(rendered).to contain_exactly(
          'Changed name from Profile to Renamed',
          'Changed trigger sbom_ingested auto_remediation.cooldown from 5 to 3',
          'Removed trigger sbom_ingested auto_remediation.upgrade_policy (was minor)',
          'Set trigger sbom_ingested auto_remediation.enabled to true',
          'Added c to trigger sbom_ingested excluded_paths; Removed a from trigger sbom_ingested excluded_paths'
        )
        expect(rendered).to match_array(audit_change_messages)
      end
    end
  end
end
