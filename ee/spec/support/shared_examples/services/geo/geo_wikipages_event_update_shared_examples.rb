# frozen_string_literal: true

RSpec.shared_examples 'WikiPages::Create|Update|DestroyService#execute sends a Geo event update' do
  include ::EE::GeoHelpers

  let_it_be(:primary, freeze: false) { create(:geo_node, :primary) }
  let_it_be(:secondary, freeze: false) { create(:geo_node) }
  let_it_be(:user, freeze: false) { create(:user) }

  let(:container) { create(:project) }

  describe '#execute' do
    context 'with geo_project_wiki_repository_replication feature flag disabled' do
      before do
        stub_feature_flags(geo_project_wiki_repository_replication: false)
      end

      context 'when on a Geo primary site' do
        before do
          stub_current_geo_node(primary)
        end

        it 'does not create a Geo::Event' do
          event_params = {
            event_name: :updated,
            replicable_name: :project_wiki_repository
          }

          expect { service_execute }
            .not_to change { ::Geo::Event.where(event_params).count }
        end
      end

      context 'when not on a Geo primary site' do
        before do
          stub_current_geo_node(secondary)
        end

        it 'does not create a Geo::Event' do
          expect { service_execute }
            .not_to change { ::Geo::Event.count }
        end
      end
    end

    context 'with geo_project_wiki_repository_replication feature flag enabled' do
      let(:event_params) { { event_name: :updated, replicable_name: :project_wiki_repository } }

      before do
        stub_feature_flags(geo_project_wiki_repository_replication: true)
      end

      context 'when on a Geo primary site' do
        before do
          stub_current_geo_node(primary)
        end

        it 'creates a Geo::Event' do
          expect { service_execute }
            .to change { ::Geo::Event.where(event_params).count }.by(1)
        end

        context 'when project has no wiki_repository record' do
          before do
            allow(container).to receive(:wiki_repository).and_return(nil)
          end

          it 'does not raise an error and does not create a Geo::Event' do
            expect { service_execute }
              .not_to change { ::Geo::Event.where(event_params).count }
          end
        end
      end

      context 'when container is a Group' do
        let(:container) { create(:group, :wiki_repo) }

        it 'does not create a Geo::Event' do
          expect { service_execute }
            .not_to change { ::Geo::Event.where(event_params).count }
        end
      end

      context 'when not on a Geo primary site' do
        before do
          stub_current_geo_node(secondary)
        end

        it 'does not create a Geo::Event' do
          expect { service_execute }
            .not_to change { ::Geo::Event.count }
        end
      end
    end
  end
end
