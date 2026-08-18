# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersions::RestoreService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: maintainer, developers: developer) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be_with_reload(:item) { create(:ai_catalog_agent, project: project) }

  let_it_be_with_reload(:version_1_0) do
    create(:ai_catalog_item_version, :released, item: item, version: '1.0.0')
  end

  let_it_be_with_reload(:version_1_1) do
    create(:ai_catalog_item_version, :released, item: item, version: '1.1.0')
  end

  let(:source_version) { version_1_0 }
  let(:deprecate_current) { false }
  let(:current_user) { maintainer }
  let(:params) { { source_version: source_version, deprecate_current: deprecate_current } }

  subject(:response) { described_class.new(project: project, current_user: current_user, params: params).execute }

  before do
    enable_ai_catalog
  end

  describe '#execute' do
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(ai_catalog_version_restore: false)
      end

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to contain_exactly('This feature is not available.')
      end
    end

    context 'when user does not have permission' do
      let(:current_user) { developer }

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to contain_exactly('You have insufficient permissions')
      end
    end

    context 'when source version is nil' do
      let(:source_version) { nil }

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to contain_exactly('You must provide a source version.')
      end
    end

    context 'when source version is not released' do
      let_it_be(:draft_version) { create(:ai_catalog_item_version, :draft, item: item, version: '2.0.0') }

      let(:source_version) { draft_version }

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to contain_exactly('Source version must be a released version.')
      end
    end

    context 'when source version is deprecated' do
      before do
        version_1_0.update!(deprecated: true)
      end

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to contain_exactly('Cannot restore a deprecated version.')
      end
    end

    context 'when source version is the current latest' do
      let(:source_version) { version_1_1 }

      before do
        item.update!(latest_released_version: version_1_1)
      end

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to contain_exactly('Source version is already the current latest version.')
      end
    end

    context 'when item has no latest released version' do
      before do
        allow(version_1_0.item).to receive(:latest_released_version_with_fallback).and_return(nil)
      end

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to contain_exactly('Item must have a current latest released version to restore.')
      end
    end

    context 'when restore succeeds' do
      before do
        item.update!(latest_released_version: version_1_1)
      end

      it 'returns a success response' do
        expect(response).to be_success
      end

      it 'creates a new version with the source definition' do
        expect { response }.to change { Ai::Catalog::ItemVersion.count }.by(1)

        new_version = response.payload[:item_version]
        expect(new_version.definition).to eq(version_1_0.definition)
        expect(new_version.schema_version).to eq(version_1_0.schema_version)
        expect(new_version.released?).to be(true)
        expect(new_version.created_by).to eq(maintainer)
        expect(new_version.version).to eq('1.2.0')
      end

      it 'updates the item latest_version and latest_released_version' do
        response

        item.reload
        new_version = response.payload[:item_version]
        expect(item.latest_version).to eq(new_version)
        expect(item.latest_released_version).to eq(new_version)
      end

      it 'tracks an internal event' do
        expect { response }.to trigger_internal_events('restore_ai_catalog_item').with(
          user: maintainer,
          project: project,
          additional_properties: {
            label: 'agent',
            item_type: 'custom_agent',
            item_version: '1.2.0',
            item_schema_version: 'v1',
            custom_item_id: item.id,
            tools: 'gitlab_blob_search',
            deprecated: 'false'
          }
        )
      end

      it 'creates an audit event' do
        expect { response }.to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.last
        expect(audit_event.author).to eq(maintainer)
        expect(audit_event.details[:custom_message]).to include(
          'Restored version 1.0.0 as new latest version 1.2.0'
        )
      end

      it 'does not deprecate the current latest version by default' do
        response

        expect(version_1_1.reload.deprecated).to be(false)
      end

      context 'when deprecate_current is true' do
        let(:deprecate_current) { true }

        it 'deprecates the current latest version' do
          response

          expect(version_1_1.reload.deprecated).to be(true)
        end

        it 'tracks the event with deprecated: true' do
          expect { response }.to trigger_internal_events('restore_ai_catalog_item').with(
            user: maintainer,
            project: project,
            additional_properties: {
              label: 'agent',
              item_type: 'custom_agent',
              item_version: '1.2.0',
              item_schema_version: 'v1',
              custom_item_id: item.id,
              tools: 'gitlab_blob_search',
              deprecated: 'true'
            }
          )
        end
      end

      context 'when item is a custom flow' do
        let_it_be_with_reload(:flow_item) { create(:ai_catalog_flow, project: project) }
        let_it_be(:flow_version_1_0) { create(:ai_catalog_flow_version, :released, item: flow_item, version: '1.0.0') }
        let_it_be(:flow_version_1_1) { create(:ai_catalog_flow_version, :released, item: flow_item, version: '1.1.0') }

        let(:source_version) { flow_version_1_0 }

        before do
          flow_item.update!(latest_released_version: flow_version_1_1)
        end

        it 'creates the version successfully' do
          expect(response).to be_success
          expect(response.payload[:item_version].version).to eq('1.2.0')
        end
      end
    end
  end
end
