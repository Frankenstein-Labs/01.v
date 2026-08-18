# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::HTTP::NamespaceFilter, feature_category: :audit_events do
  let_it_be(:filter_group) { create(:group) }
  let(:destination) { create(:external_audit_event_destination, group: filter_group) }

  subject do
    build(:audit_events_streaming_http_namespace_filter, external_audit_event_destination: destination,
      namespace: filter_group)
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:external_audit_event_destination) }
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:external_audit_event_destination) }
    it { is_expected.to validate_uniqueness_of(:namespace) }
    it { is_expected.to validate_uniqueness_of(:external_audit_event_destination) }

    describe 'validates external destination with namespace' do
      let_it_be(:grandparent_group) { create(:group) }
      let_it_be(:parent_group) { create(:group, parent: grandparent_group) }

      shared_examples 'validate namespace with external destination' do |namespace_type|
        let_it_be(:namespace) { create(namespace_type.to_sym, parent: parent_group) }

        context 'when external destination belongs to root ancestor of namespace' do
          let(:destination) { create(:external_audit_event_destination, group: grandparent_group) }

          subject do
            build(:audit_events_streaming_http_namespace_filter, namespace: namespace,
              external_audit_event_destination: destination)
          end

          it { is_expected.to be_valid }
        end

        context 'when external destination does not belong to root ancestor of namespace' do
          it 'returns error' do
            destination = create(:external_audit_event_destination, group: create(:group))
            namespace_filter = build(:audit_events_streaming_http_namespace_filter, namespace: namespace,
              external_audit_event_destination: destination)

            expect(namespace_filter).to be_invalid
            expect(namespace_filter.errors.full_messages)
              .to contain_exactly(
                'External audit event destination does not belong to the top-level group of the namespace.'
              )
          end
        end
      end

      context 'when namespace is group' do
        it_behaves_like 'validate namespace with external destination', 'group'
      end

      context 'when namespace is project' do
        it_behaves_like 'validate namespace with external destination', 'project_namespace'
      end

      context 'when namespace is neither project nor group' do
        it 'returns error' do
          namespace_filter = build(:audit_events_streaming_http_namespace_filter, namespace: create(:user_namespace),
            external_audit_event_destination: destination)

          expect(namespace_filter).to be_invalid
          expect(namespace_filter.errors.full_messages)
            .to include("Namespace is not supported. Only project and group are supported.")
        end
      end
    end
  end
end
