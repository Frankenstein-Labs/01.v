# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Protection::InternalEventsTracking, feature_category: :container_registry do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:service_class) do
    Class.new do
      include ContainerRegistry::Protection::InternalEventsTracking

      attr_reader :current_user

      def initialize(current_user)
        @current_user = current_user
      end
    end
  end

  let(:service) { service_class.new(user) }

  describe '#track_tag_rule_creation' do
    context 'when protection rule is immutable' do
      let(:protection_rule) { create(:container_registry_protection_tag_rule, :immutable, project: project) }

      it 'tracks with immutable rule type' do
        expect(service).to receive(:track_internal_event).with(
          'create_container_registry_protected_tag_rule',
          project: project,
          namespace: project.namespace,
          user: user,
          additional_properties: { rule_type: 'immutable' }
        )

        service.track_tag_rule_creation(protection_rule)
      end
    end
  end
end
