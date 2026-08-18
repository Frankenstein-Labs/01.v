# frozen_string_literal: true

require 'spec_helper'
require_relative './shared_examples/events_tracking'

RSpec.describe Ai::Catalog::ItemConsumers::UpdateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  it_behaves_like 'ItemConsumers::EventsTracking' do
    subject { described_class.new(build(:ai_catalog_item_consumer), build(:user), {}) }
  end

  before do
    enable_ai_catalog
  end

  describe '#execute' do
    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:group) { create(:group, developers: developer, maintainers: maintainer) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:item_project, freeze: false) { create(:project, maintainers: maintainer, group: group) }
    let_it_be(:item, freeze: false) { create(:ai_catalog_item, :public, project: item_project) }

    let(:pinned_version_prefix) { latest_released_version.version }
    let(:params) { { pinned_version_prefix: pinned_version_prefix } }

    subject(:response) { described_class.new(item_consumer, user, params).execute }

    shared_examples 'error' do |message:|
      it 'does not change the item consumer and returns the error message' do
        expect { response }.not_to change { item_consumer.reload.attributes }
        expect(response).to be_error
        expect(response.message).to contain_exactly(message)
      end

      it 'does not track internal event' do
        expect { response }.not_to trigger_internal_events('update_ai_catalog_item_consumer')
      end

      it 'does not create an audit event' do
        expect { response }.not_to change { AuditEventReader.count }
      end
    end

    shared_examples 'Ai::Catalog::ItemConsumers::UpdateService' do
      let_it_be(:older_released_version, freeze: false) do
        create(:ai_catalog_item_version, :released, item: item_consumer.item, version: '1.0.0', project: item_project)
      end

      let_it_be(:latest_released_version, freeze: false) do
        create(:ai_catalog_item_version, :released, item: item_consumer.item, version: '2.0.0', project: item_project)
      end

      let_it_be(:latest_draft_version) do
        create(:ai_catalog_item_version, :draft, item: item_consumer.item, version: '3.0.0', project: item_project)
      end

      context 'when user does not have permission' do
        let(:user) { developer }

        it_behaves_like 'error', message: "You don't have permission to update this configuration"
      end

      context 'when user has permission' do
        let(:user) { maintainer }

        it 'returns success response' do
          expect(response).to be_success
        end

        it 'updates the item consumer' do
          expect { response }
            .to change { item_consumer.reload.pinned_version_prefix }
            .to(latest_released_version.version)
        end

        it 'tracks internal event on successful update' do
          stub_event_properties_builder

          expect { response }.to trigger_internal_events('update_ai_catalog_item_consumer').with(
            user: maintainer,
            project: item_consumer.project,
            namespace: item_consumer.group,
            additional_properties: stubbed_event_properties.merge(
              label: 'true',
              property: 'true'
            )
          ).and increment_usage_metrics('counts.count_total_update_ai_catalog_item_consumer')
        end

        it 'creates an audit event with correct attributes', :aggregate_failures do
          item_consumer.reload
          item = item_consumer.item
          event_name = "update_enabled_ai_catalog_#{item.item_type}"
          custom_message = "Updated enabled AI #{item.human_item_type} " \
            "to version #{pinned_version_prefix}"

          expect { response }.to change { AuditEventReader.count }.by(1)
          expect(AuditEventReader.last).to have_attributes(
            author: maintainer,
            target_details: "#{item_consumer.item.name} (ID: #{item_consumer.item.id})",
            details: include(
              event_name: event_name,
              target_type: 'Ai::Catalog::Item',
              custom_message: custom_message
            )
          )
        end

        context 'when the pinned_version_prefix is of a draft version' do
          let(:pinned_version_prefix) { latest_draft_version.version }

          it_behaves_like 'error',
            message: 'pinned_version_prefix must resolve to a released version of the agent or flow'
        end

        context 'when the pinned_version_prefix is not of a version that exists' do
          let(:pinned_version_prefix) { '12.34.56' }

          before do
            allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
          end

          it_behaves_like 'error',
            message: 'pinned_version_prefix must resolve to a released version of the agent or flow'
        end

        context 'when the pinned_version_prefix is of an older released version' do
          let(:pinned_version_prefix) { older_released_version.version }

          it 'returns success and updates the item consumer to the older released version',
            :aggregate_failures do
            expect(response).to be_success
            expect(item_consumer.reload.pinned_version_prefix).to eq(older_released_version.version)
          end
        end

        context 'when the pinned_version_prefix is nil' do
          let(:pinned_version_prefix) { nil }

          it_behaves_like 'error',
            message: 'pinned_version_prefix must be present'
        end

        context 'when the pinned_version_prefix is not given' do
          let(:params) { super().except(:pinned_version_prefix) }

          it 'is successful, but a no-op' do
            # Note, will be a no-op until the service can update another attribute
            expect { response }.not_to change { item_consumer.reload.attributes }
            expect(response).to be_success
          end

          it 'does not create an audit event' do
            expect { response }.not_to change { AuditEventReader.count }
          end
        end

        context 'when the item consumer cannot be updated' do
          before do
            allow_next_instance_of(::Ai::Catalog::ItemConsumers::UpdateService) do |service|
              allow(service).to receive(:item_consumer).and_return(item_consumer)
            end

            allow(item_consumer).to receive(:update).and_return(false)
            item_consumer.errors.add(:base, 'Update failed')
          end

          it_behaves_like 'error', message: 'Update failed'
        end
      end
    end

    context 'with a project level item consumer' do
      let_it_be_with_reload(:item_consumer) do
        create(:ai_catalog_item_consumer, project: project, item: item, pinned_version_prefix: '1.0.0')
      end

      it_behaves_like 'Ai::Catalog::ItemConsumers::UpdateService'

      context 'when the item consumer belongs to the same project that owns the item' do
        let(:user) { maintainer }

        before_all do
          item_consumer.update!(project: item_project)
        end

        context 'when pinned_version_prefix is nil' do
          let(:pinned_version_prefix) { nil }

          it 'updates the pinned_version_prefix to nil' do
            expect(response).to be_success
            expect(item_consumer.reload.pinned_version_prefix).to be_nil
          end
        end

        context 'when pinned_version_prefix is a valid version' do
          let_it_be(:latest_released_version, freeze: false) do
            create(:ai_catalog_item_version, :released, item: item, version: '2.0.0', project: item_project)
          end

          let(:pinned_version_prefix) { latest_released_version.version }

          it 'automatically sets pinned_version_prefix to nil for owner project' do
            expect(response).to be_success
            expect(item_consumer.reload.pinned_version_prefix).to be_nil
          end
        end
      end
    end

    context 'with a group level item consumer' do
      let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, group: group, item: item) }

      it_behaves_like 'Ai::Catalog::ItemConsumers::UpdateService'
    end
  end
end
