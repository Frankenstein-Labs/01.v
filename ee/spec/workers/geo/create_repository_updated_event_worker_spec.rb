# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::CreateRepositoryUpdatedEventWorker, feature_category: :geo_replication do
  include ::EE::GeoHelpers
  include AfterNextHelpers

  let_it_be(:primary_site) { create(:geo_node, :primary) }
  let_it_be(:secondary_site) { create(:geo_node) }
  let_it_be(:project) { create(:project) }

  let(:event) { ::Repositories::KeepAroundRefsCreatedEvent.new(data: { project_id: project.id }) }

  subject(:consume) { consume_event(subscriber: described_class, event: event) }

  context 'on a Geo primary site' do
    before do
      stub_current_geo_node(primary_site)
      stub_feature_flags(geo_project_repository_replication_v2: false)
    end

    it_behaves_like 'subscribes to event'
    it_behaves_like 'ignores the published event' do
      before do
        stub_secondary_site
      end
    end

    it 'consumes the published event', :sidekiq_inline do
      expect_next(described_class)
        .to receive(:handle_event)
        .with(instance_of(event.class))
        .and_call_original

      expect { consume }.to change { ::Geo::Event.where(event_name: :updated).count }.by(1)
    end

    context 'when project does not exist' do
      let(:event) { ::Repositories::KeepAroundRefsCreatedEvent.new(data: { project_id: non_existing_record_id }) }

      it 'does not create a Geo event' do
        expect { consume }.not_to change { ::Geo::Event.count }
      end
    end
  end
end
