# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRepository, feature_category: :container_registry do
  describe '.search' do
    let_it_be_with_reload(:container_repository1) { create(:container_repository) }
    let_it_be(:container_repository2) { create(:container_repository) }
    let_it_be(:container_repository3) { create(:container_repository) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(container_repository1, container_repository2, container_repository3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all container repositories' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches' do
        context 'with matches by attributes' do
          where(:searchable_attributes) { described_class::EE_SEARCHABLE_ATTRIBUTES }

          before do
            # Use update_column to bypass attribute validations like regex formatting, checksum, etc.
            container_repository1.update_column(searchable_attributes, 'any_keyword')
          end

          with_them do
            it do
              result = described_class.search('any_keyword')

              expect(result).to contain_exactly(container_repository1)
            end
          end
        end
      end
    end
  end

  describe 'Geo', feature_category: :geo_replication do
    before do
      stub_container_registry_config(enabled: true)
    end

    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:container_repository_state)
                .class_name('Geo::ContainerRepositoryState')
                .inverse_of(:container_repository)
                .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:container_repository) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      context 'when the container registry is enabled' do
        let_it_be(:group_1) { create(:group, organization: create(:organization)) }
        # Container repository for the root group
        let!(:first_replicable_and_in_selective_sync) do
          create(:container_repository, project: project_1)
        end

        # Container repository for a subgroup
        let!(:second_replicable_and_in_selective_sync) do
          create(:container_repository, project: project_2)
        end

        # Container repository for a group not in selective sync (on broken storage shard)
        let!(:last_replicable_and_not_in_selective_sync) do
          create(:container_repository, project: project_3)
        end

        let_it_be(:group_2) { create(:group, organization: create(:organization)) }
        let_it_be(:nested_group_1) { create(:group, parent: group_1) }
        let_it_be(:project_1) { create(:project, group: group_1) }
        let_it_be(:project_2) { create(:project, group: nested_group_1) }
        let_it_be(:project_3) { create(:project, :broken_storage, group: group_2) }

        before do
          stub_registry_replication_config(enabled: true)
        end

        include_examples 'Geo Framework selective sync behavior'
      end
    end
  end

  describe '#push_blob' do
    it "calls client's push blob with path passed" do
      gitlab_container_repository = create(:container_repository)
      client = instance_double("ContainerRegistry::Client")
      allow(gitlab_container_repository).to receive(:client).and_return(client)

      expect(client).to receive(:push_blob).with(gitlab_container_repository.path, 'a123cd', ['body'], 32456)

      gitlab_container_repository.push_blob('a123cd', ['body'], 32456)
    end
  end

  describe '#protected_from_delete_by_tag_rules?' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:project) { create(:project, path: 'test') }
    let_it_be_with_refind(:repository) do
      create(:container_repository, name: 'my_image', project: project)
    end

    subject { repository.protected_from_delete_by_tag_rules?(current_user) }

    context 'when the user is nil' do
      let(:current_user) { nil }

      it { is_expected.to be_truthy }
    end

    context 'when immutable tag rules are present' do
      before_all do
        create(
          :container_registry_protection_tag_rule,
          :immutable,
          tag_name_pattern: 'tag',
          project: project
        )
      end

      context 'when the licensed feature is enabled' do
        before do
          allow(repository).to receive(:has_tags?).and_return(has_tags)
          stub_licensed_features(container_registry_immutable_tag_rules: true)
        end

        let(:has_tags) { true }

        it { is_expected.to be(true) }

        context 'when no tags' do
          let(:has_tags) { false }

          it { is_expected.to be(false) }
        end
      end

      context 'when the licensed feature is not enabled' do
        before do
          stub_licensed_features(container_registry_immutable_tag_rules: false)
        end

        it_behaves_like 'checking mutable tag rules on a container repository'
      end
    end

    context 'when there are no immutable tag rules' do
      it_behaves_like 'checking mutable tag rules on a container repository'
    end
  end
end
