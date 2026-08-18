# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Group::NamespaceFilter, feature_category: :audit_events do
  subject(:namespace_filter) { build(:audit_events_streaming_group_namespace_filters) }

  let_it_be(:destination) { create(:audit_events_group_external_streaming_destination) }

  describe 'Associations' do
    it { is_expected.to belong_to(:external_streaming_destination).class_name('ExternalStreamingDestination') }
    it { is_expected.to belong_to(:namespace).inverse_of(:audit_events_streaming_group_namespace_filters) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:external_streaming_destination) }
    it { is_expected.to validate_uniqueness_of(:namespace).scoped_to(:external_streaming_destination_id) }

    describe 'validates external destination with namespace' do
      let_it_be(:grandparent_group) { create(:group) }
      let_it_be(:parent_group) { create(:group, parent: grandparent_group) }

      shared_examples 'validate namespace with external destination' do |namespace_type|
        let_it_be(:namespace) { create(namespace_type.to_sym, parent: parent_group) }

        context 'when external destination belongs to root ancestor of namespace' do
          let(:destination) { create(:audit_events_group_external_streaming_destination, group: grandparent_group) }

          subject do
            build(:audit_events_streaming_group_namespace_filters, namespace: namespace,
              external_streaming_destination: destination)
          end

          it { is_expected.to be_valid }
        end

        context 'when external destination does not belong to root ancestor of namespace' do
          it 'returns error' do
            destination = create(:audit_events_group_external_streaming_destination, group: create(:group))
            namespace_filter = build(:audit_events_streaming_group_namespace_filters, namespace: namespace,
              external_streaming_destination: destination)

            expect(namespace_filter).to be_invalid
            expect(namespace_filter.errors.full_messages)
              .to contain_exactly(
                _('External streaming destination does not belong to the top-level group of the namespace.')
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
          namespace_filter = build(:audit_events_streaming_group_namespace_filters,
            namespace: create(:user_namespace),
            external_streaming_destination: destination)

          expect(namespace_filter).to be_invalid
          expect(namespace_filter.errors.full_messages)
            .to include("Namespace is not supported. Only project and group are supported.")
        end
      end
    end
  end
end
