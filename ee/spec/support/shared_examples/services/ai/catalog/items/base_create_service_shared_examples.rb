# frozen_string_literal: true

RSpec.shared_examples Ai::Catalog::Items::BaseCreateService do
  subject(:execute_service) { service.execute }

  shared_examples 'an error response' do |errors|
    it 'returns an error response' do
      result = execute_service

      expect(result).to be_error
      expect(result.message).to match_array(Array(errors))
      expect(result.payload).to be_empty
    end

    it 'does not create an item' do
      expect { execute_service }.not_to change { Ai::Catalog::Item.count }
    end

    it 'does not trigger create_ai_catalog_item', :clean_gitlab_redis_shared_state do
      expect { execute_service }
        .not_to trigger_internal_events('create_ai_catalog_item')
    end

    it 'does not create an audit event' do
      expect { execute_service }.not_to change { AuditEventReader.count }
    end
  end

  describe '#execute', :freeze_time do
    it 'returns a success response with item in payload' do
      result = execute_service

      expect(result).to be_success
      expect(result.payload[:item]).to be_a(Ai::Catalog::Item)
    end

    it 'creates a catalog item and version with expected data' do
      expect { execute_service }.to change { Ai::Catalog::Item.count }.by(1)
        .and change { Ai::Catalog::ItemVersion.count }.by(1)

      item = Ai::Catalog::Item.last

      expect(item).to have_attributes(
        name: params[:name],
        description: params[:description],
        visibility: params[:visibility].to_s,
        item_type: expected_item_type.to_s
      )
      expect(item.latest_version).to have_attributes(
        schema_version: expected_item_schema_version,
        version: '1.0.0',
        release_date: Time.zone.now,
        definition: expected_updated_definition.stringify_keys,
        created_by: user
      )
      expect(item.latest_released_version).to be_kind_of(Ai::Catalog::ItemVersion)
      expect(item.latest_released_version).to eq(item.latest_version)
    end

    it 'triggers create_ai_catalog_item', :clean_gitlab_redis_shared_state do
      expect { execute_service }
       .to trigger_internal_events('create_ai_catalog_item')
       .with(user: user, project: project, additional_properties: expected_create_event_properties)
       .and increment_usage_metrics(
         'redis_hll_counters.count_distinct_user_id_from_create_ai_catalog_item_weekly',
         'redis_hll_counters.count_distinct_user_id_from_create_ai_catalog_item_monthly',
         'counts.count_total_create_ai_catalog_item'
       )
    end

    it 'creates an audit event', :aggregate_failures do
      expect { execute_service }.to change { AuditEventReader.count }.by(2)

      audit_events = AuditEventReader.last(2)
      item = Ai::Catalog::Item.last

      expect(audit_events[0]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_events[0].details).to include(
        custom_message: expected_audit_event_create_item_message,
        event_name: "create_ai_catalog_#{expected_item_type}",
        target_type: 'Ai::Catalog::Item'
      )

      expect(audit_events[1]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_events[1].details).to include(
        custom_message: "Released version 1.0.0 of #{expected_audit_event_item_name}"
      )
    end

    context 'when there is a validation issue' do
      before do
        params[:name] = nil
      end

      it_behaves_like 'an error response', ["Name can't be blank"]
    end

    context 'when using the legacy public argument instead of visibility' do
      before do
        params.delete(:visibility)
        params[:public] = true
      end

      it 'creates an item with public visibility' do
        execute_service

        expect(Ai::Catalog::Item.last).to have_attributes(visibility: 'public')
      end
    end

    context 'when user is a developer' do
      let(:user) { create(:user).tap { |user| project.add_developer(user) } }

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end
  end
end
