# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::HTTP::Instance::NamespaceFilter, feature_category: :audit_events do
  let_it_be(:filter_group) { create(:group) }
  let(:destination) { create(:instance_external_audit_event_destination) }

  subject do
    build(:audit_events_streaming_http_instance_namespace_filter,
      instance_external_audit_event_destination: destination,
      namespace: filter_group)
  end

  describe 'Associations' do
    it { is_expected.to belong_to(:instance_external_audit_event_destination) }
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:instance_external_audit_event_destination) }
    it { is_expected.to validate_uniqueness_of(:instance_external_audit_event_destination) }

    describe 'validates external destination with namespace' do
      shared_examples 'validate namespace with external destination' do |namespace_type|
        let_it_be(:namespace) { build(namespace_type.to_sym) }

        let(:destination) { create(:instance_external_audit_event_destination) }

        subject do
          build(:audit_events_streaming_http_instance_namespace_filter, namespace: namespace,
            instance_external_audit_event_destination: destination)
        end

        it { is_expected.to be_valid }
      end

      context 'when namespace is group' do
        it_behaves_like 'validate namespace with external destination', 'group'
      end

      context 'when namespace is project' do
        it_behaves_like 'validate namespace with external destination', 'project_namespace'
      end

      context 'when namespace is neither project nor group' do
        it 'returns error' do
          namespace_filter = build(:audit_events_streaming_http_instance_namespace_filter,
            namespace: create(:user_namespace),
            instance_external_audit_event_destination: destination)

          expect(namespace_filter).to be_invalid
          expect(namespace_filter.errors.full_messages)
            .to include("Namespace is not supported. Only project and group are supported.")
        end
      end
    end
  end
end
