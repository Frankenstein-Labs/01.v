# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::FoundationalFlows::SyncService, feature_category: :ai_abstraction_layer do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:flow1) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }
  let_it_be(:flow2) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }
  let_it_be(:flow3) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }

  let(:container) { group }
  let(:target_ids) { [flow1.id, flow2.id] }

  subject(:service) { described_class.new(container: container, target_ids: target_ids) }

  shared_examples 'syncs enabled foundational flows' do
    it 'returns success' do
      result = service.execute

      expect(result).to be_success
    end

    context 'when target_ids is empty' do
      let(:target_ids) { [] }

      it 'deletes all existing flows' do
        create(:ai_catalog_enabled_foundational_flow, :"for_#{container_type}", container_type => container,
          catalog_item: flow1)
        create(:ai_catalog_enabled_foundational_flow, :"for_#{container_type}", container_type => container,
          catalog_item: flow2)

        expect { service.execute }.to change {
          Ai::Catalog::EnabledFoundationalFlow.public_send(:"for_#{container_type}", container.id).count
        }.from(2).to(0)
      end
    end

    context 'when target_ids contains new flows' do
      it 'creates new flow records' do
        expect { service.execute }.to change {
          Ai::Catalog::EnabledFoundationalFlow.public_send(:"for_#{container_type}", container.id).count
        }.from(0).to(2)

        flow_records = Ai::Catalog::EnabledFoundationalFlow.public_send(:"for_#{container_type}", container.id)
        expect(flow_records.pluck(:catalog_item_id)).to match_array([flow1.id, flow2.id])
      end

      it 'sets timestamps correctly' do
        freeze_time do
          service.execute

          flow_records = Ai::Catalog::EnabledFoundationalFlow.public_send(:"for_#{container_type}", container.id)
          flow_records.each do |record|
            expect(record.created_at).to eq(Time.current)
            expect(record.updated_at).to eq(Time.current)
          end
        end
      end
    end

    context 'when some flows already exist' do
      before do
        create(:ai_catalog_enabled_foundational_flow, :"for_#{container_type}", container_type => container,
          catalog_item: flow1)
        create(:ai_catalog_enabled_foundational_flow, :"for_#{container_type}", container_type => container,
          catalog_item: flow3)
      end

      it 'keeps existing flows that are in target_ids' do
        service.execute

        flow_records = Ai::Catalog::EnabledFoundationalFlow.public_send(:"for_#{container_type}", container.id)
        expect(flow_records.count).to eq(2)
        expect(flow_records.pluck(:catalog_item_id)).to match_array([flow1.id, flow2.id])
      end

      it 'removes flows not in target_ids' do
        service.execute

        expect(
          Ai::Catalog::EnabledFoundationalFlow
            .public_send(:"for_#{container_type}", container.id)
            .where(catalog_item_id: flow3.id)
        ).not_to exist
      end

      it 'adds new flows from target_ids' do
        service.execute

        expect(
          Ai::Catalog::EnabledFoundationalFlow
            .public_send(:"for_#{container_type}", container.id)
            .where(catalog_item_id: flow2.id)
        ).to exist
      end
    end

    context 'when target_ids has duplicates' do
      let(:target_ids) { [flow1.id, flow1.id, flow2.id] }

      it 'creates only unique records' do
        expect { service.execute }.to change {
          Ai::Catalog::EnabledFoundationalFlow.public_send(:"for_#{container_type}", container.id).count
        }.from(0).to(2)
      end
    end

    context 'when record validation fails' do
      before do
        allow_next_instance_of(Ai::Catalog::EnabledFoundationalFlow) do |flow|
          allow(flow).to receive_messages(
            valid?: false,
            errors: instance_double(ActiveModel::Errors, full_messages: ['Validation error'])
          )
        end
      end

      it 'tracks the exception and returns error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(ActiveRecord::RecordInvalid),
          hash_including(
            target_ids: target_ids,
            container_id_key => container.id
          )
        )

        result = service.execute

        expect(result).to be_error
      end
    end

    context 'when bulk_insert! raises an exception' do
      before do
        allow(Ai::Catalog::EnabledFoundationalFlow).to receive(:bulk_insert!).and_raise(
          ActiveRecord::RecordInvalid.new(
            Ai::Catalog::EnabledFoundationalFlow.new(catalog_item_id: flow1.id)
          )
        )
      end

      it 'tracks the exception and returns error response' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(ActiveRecord::RecordInvalid),
          hash_including(
            target_ids: target_ids,
            container_id_key => container.id,
            validation_errors: ''
          )
        )

        result = service.execute

        expect(result).to be_error
        expect(result.message).to be_present
      end
    end
  end

  describe '#execute' do
    context 'when container is a namespace' do
      let(:container) { group }
      let(:container_type) { :namespace }
      let(:container_id_key) { :namespace_id }

      it_behaves_like 'syncs enabled foundational flows'
    end

    context 'when container is a project' do
      let(:container) { project }
      let(:container_type) { :project }
      let(:container_id_key) { :project_id }

      it_behaves_like 'syncs enabled foundational flows'
    end
  end
end
