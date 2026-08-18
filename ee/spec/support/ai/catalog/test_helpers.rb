# frozen_string_literal: true

module Ai
  module Catalog
    module TestHelpers
      def enable_ai_catalog(enabled = true)
        allow(Ai::Catalog).to receive(:available?).and_return(enabled)
        allow(Gitlab::Llm::StageCheck).to receive(:available?).and_return(enabled)
        stub_licensed_features(ai_catalog: enabled)
        stub_dws_flow_config_validation if enabled
      end

      def stubbed_event_properties
        { item_type: 'custom_flow', custom_item_id: 42 }
      end

      def stub_event_properties_builder(item_consumer = nil)
        builder = instance_double(
          Ai::Catalog::Tracking::EventPropertiesBuilder,
          to_h: stubbed_event_properties
        )

        receiver = allow(Ai::Catalog::Tracking::EventPropertiesBuilder).to receive(:new)
        receiver = receiver.with(item: item_consumer.item, version: item_consumer.pinned_version) if item_consumer

        receiver.and_return(builder)
      end

      def stub_stage_checks(container, flows: false, third_party_flows: false, foundational_flows: false)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(container, :ai_catalog).and_return(true)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(container, :ai_catalog_flows).and_return(flows)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(container, :ai_catalog_third_party_flows).and_return(third_party_flows)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(container, :foundational_flows).and_return(foundational_flows)
      end

      def stub_dws_flow_config_validation
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:validate_flow_config).and_return(ServiceResponse.success)
        end
      end

      def click_more_actions_dropdown
        click_button 'More actions'
      end

      def click_more_actions_button(text)
        click_more_actions_dropdown
        click_button text
      end
    end
  end
end
