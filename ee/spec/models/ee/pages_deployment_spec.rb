# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PagesDeployment, feature_category: :pages do
  describe '.search' do
    let_it_be_with_reload(:pages_deployment1) { create(:pages_deployment) }
    let_it_be(:pages_deployment2) { create(:pages_deployment) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(pages_deployment1, pages_deployment2)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all records' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches by attributes' do
        where(:searchable_attribute) { described_class::EE_SEARCHABLE_ATTRIBUTES }

        before do
          # Use update_column to bypass attribute validations like regex formatting, checksum, etc.
          pages_deployment1.update_column(searchable_attribute, 'any_keyword')
        end

        with_them do
          it do
            result = described_class.search('any_keyword')

            expect(result).to contain_exactly(pages_deployment1)
          end
        end
      end
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:pages_deployment_state)
          .class_name('Geo::PagesDeploymentState')
          .inverse_of(:pages_deployment)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) { build(:pages_deployment) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      # Pages deployment for the root group
      let!(:first_replicable_and_in_selective_sync) do
        stub_pages_object_storage(::Pages::DeploymentUploader, enabled: false)
        create(:pages_deployment, project: project_1)
      end

      # Pages deployment for a subgroup
      let!(:second_replicable_and_in_selective_sync) do
        stub_pages_object_storage(::Pages::DeploymentUploader, enabled: false)
        create(:pages_deployment, project: project_2)
      end

      # Pages deployment for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_pages_object_storage(::Pages::DeploymentUploader, enabled: true)
        create(:pages_deployment, :object_storage, project: project_1)
      end

      # Pages deployment for a group not in selective sync
      let!(:last_replicable_and_not_in_selective_sync) do
        stub_pages_object_storage(::Pages::DeploymentUploader, enabled: false)
        create(:pages_deployment, project: project_3)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
