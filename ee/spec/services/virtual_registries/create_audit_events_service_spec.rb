# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::CreateAuditEventsService, feature_category: :virtual_registry do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }
  let(:upstream) { build_stubbed(:virtual_registries_packages_maven_upstream, group:) }
  let(:entries) { [] }
  let(:event_name) { 'virtual_registries_packages_maven_cache_remote_entry_deleted' }
  let(:service) { described_class.new(entries:, event_name:) }

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when event name is invalid' do
      let(:event_name) { 'invalid_event_name' }

      it { is_expected.to be_error.and have_attributes(message: 'Invalid event name') }
    end

    context 'when no entries are provided' do
      it { is_expected.to be_error.and have_attributes(message: 'No entries to audit') }

      it 'does not create audit events' do
        expect { execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when entries are provided', :request_store do
      let(:entries) do
        build_list(:virtual_registries_packages_maven_cache_remote_entry, 3, upstream:)
      end

      let(:operation) { execute }
      let(:event_type) { event_name }
      let(:event_count) { entries.size }
      let(:fail_condition!) { allow(entries).to receive(:empty?).and_return(true) }

      let(:attributes) do
        entries.map do |entry|
          {
            author_id: user.id,
            entity_id: group.id,
            entity_type: group.class.name,
            details: {
              author_name: user.name,
              author_class: user.class.name,
              event_name: event_type,
              target_id: entry.id,
              target_type: entry.class.name,
              target_details: "#{entry.relative_path} marked for deletion by cleanup policy",
              custom_message: 'Marked cache entry for deletion'
            }
          }
        end
      end

      before do
        allow(group).to receive(:first_owner).and_return(user)
      end

      it { is_expected.to be_success }

      include_examples 'audit event logging'

      context 'when an error occurs during auditing' do
        before do
          allow_next_instance_of(Gitlab::Audit::Auditor) do |instance|
            allow(instance).to receive(:build_event).and_raise(StandardError, 'audit failure')
          end
        end

        it { is_expected.to be_error.and have_attributes(message: 'audit failure') }

        it 'does not create audit events' do
          expect { execute }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
