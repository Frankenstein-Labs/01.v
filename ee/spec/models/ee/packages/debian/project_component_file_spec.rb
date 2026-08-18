# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Debian::ProjectComponentFile, feature_category: :package_registry do
  describe 'scopes' do
    describe '.project_id_in' do
      let_it_be(:project) { create(:project) }
      let_it_be(:other_project) { create(:project) }
      let_it_be(:distribution) { create(:debian_project_distribution, container: project) }
      let_it_be(:other_distribution) { create(:debian_project_distribution, container: other_project) }
      let_it_be(:component) { create(:debian_project_component, distribution: distribution) }
      let_it_be(:other_component) { create(:debian_project_component, distribution: other_distribution) }
      let_it_be(:component_file) { create(:debian_project_component_file, component: component) }
      let_it_be(:other_component_file) { create(:debian_project_component_file, component: other_component) }

      subject { described_class.project_id_in([project.id]) }

      it { is_expected.to contain_exactly(component_file) }

      it 'does not produce N+1 queries as the number of matching files grows' do
        control = ActiveRecord::QueryRecorder.new do
          described_class.project_id_in([project.id]).each(&:id)
        end

        create_list(:debian_project_component_file, 3, component: component)

        expect do
          described_class.project_id_in([project.id]).each(&:id)
        end.not_to exceed_query_limit(control)
      end
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:packages_debian_project_component_file_state)
          .class_name('Geo::PackagesDebianProjectComponentFileState')
          .inverse_of(:packages_debian_project_component_file)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:debian_project_component_file, :with_persisted_chain) }
      let(:unverifiable_model_record) { nil }
    end

    describe '.create_verification_details_for' do
      let_it_be(:distribution_a) { create(:debian_project_distribution) }
      let_it_be(:distribution_b) { create(:debian_project_distribution) }
      let_it_be(:component_a) { create(:debian_project_component, distribution: distribution_a) }
      let_it_be(:component_b) { create(:debian_project_component, distribution: distribution_b) }
      let_it_be(:file_a) { create(:debian_project_component_file, component: component_a) }
      let_it_be(:file_b) { create(:debian_project_component_file, component: component_b) }

      it 'populates project_id on each state row from the direct project_id column' do
        described_class.create_verification_details_for([file_a.id, file_b.id])

        state_class = Geo::PackagesDebianProjectComponentFileState
        state_a = state_class.find_by(packages_debian_project_component_file_id: file_a.id)
        state_b = state_class.find_by(packages_debian_project_component_file_id: file_b.id)

        expect(state_a.project_id).to eq(distribution_a.project_id)
        expect(state_b.project_id).to eq(distribution_b.project_id)
      end
    end

    describe 'destroy cascade Geo events' do
      let_it_be(:primary) { create(:geo_node, :primary) }
      let_it_be(:secondary) { create(:geo_node) }

      before do
        stub_current_geo_node(primary)
        stub_feature_flags(geo_packages_debian_project_component_file_replication: true)
      end

      it 'creates a deleted Geo::Event for each ComponentFile when the parent Distribution is destroyed' do
        distribution = create(:debian_project_distribution)
        component = create(:debian_project_component, distribution: distribution)
        create_list(:debian_project_component_file, 2, component: component)

        replicable_name = Geo::PackagesDebianProjectComponentFileReplicator.replicable_name

        expect do
          distribution.destroy!
        end.to change {
          ::Geo::Event.where(
            replicable_name: replicable_name,
            event_name: ::Geo::ReplicatorEvents::EVENT_DELETED
          ).count
        }.by(2)
      end

      context 'when the geo_packages_debian_project_component_file_replication feature flag is disabled' do
        before do
          stub_feature_flags(geo_packages_debian_project_component_file_replication: false)
        end

        it 'does not create Geo::Events when the parent Distribution is destroyed' do
          distribution = create(:debian_project_distribution)
          component = create(:debian_project_component, distribution: distribution)
          create_list(:debian_project_component_file, 2, component: component)

          replicable_name = Geo::PackagesDebianProjectComponentFileReplicator.replicable_name

          expect do
            distribution.destroy!
          end.not_to change {
            ::Geo::Event.where(
              replicable_name: replicable_name,
              event_name: ::Geo::ReplicatorEvents::EVENT_DELETED
            ).count
          }
        end
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      let_it_be(:distribution_1) { create(:debian_project_distribution, container: project_1) }
      let_it_be(:distribution_2) { create(:debian_project_distribution, container: project_2) }
      let_it_be(:distribution_3) { create(:debian_project_distribution, container: project_3) }

      # Component file for the root group
      let!(:first_replicable_and_in_selective_sync) do
        create(:debian_project_component_file,
          component: create(:debian_project_component, distribution: distribution_1)).tap(&:reload)
      end

      # Component file for a subgroup
      let!(:second_replicable_and_in_selective_sync) do
        create(:debian_project_component_file,
          component: create(:debian_project_component, distribution: distribution_2)).tap(&:reload)
      end

      # Debian ComponentFile does not include ObjectStorable, so Geo does not
      # distinguish local vs remote file_store. Object storage tests are skipped
      # for non-object-storable models. The shared example only references this
      # variable conditionally.
      let!(:third_replicable_on_object_storage_and_in_selective_sync) { nil }

      # Component file for a group not in selective sync
      let!(:last_replicable_and_not_in_selective_sync) do
        create(:debian_project_component_file,
          component: create(:debian_project_component, distribution: distribution_3)).tap(&:reload)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
