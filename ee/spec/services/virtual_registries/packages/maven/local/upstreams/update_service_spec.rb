# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Local::Upstreams::UpdateService, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group:) }
  let_it_be_with_reload(:upstream) do
    create(:virtual_registries_packages_maven_local_upstream, registries: [registry], group: group)
  end

  let(:service) { described_class.new(upstream: upstream, current_user: user, params: params) }
  let(:params) do
    {
      name:,
      description:,
      local_project_id:,
      local_group_id:,
      cache_validity_hours:,
      metadata_cache_validity_hours:
    }.compact
  end

  describe '#execute' do
    let_it_be_with_reload(:other_project) { create(:project, owners: [user]) }
    let_it_be(:other_group) { create(:group, owners: [user]) }

    shared_examples 'updating an upstream' do
      it 'updates the upstream entry successfully' do
        expect(execute).to be_success
        expect(execute.payload).to have_attributes(expected_attributes)
      end
    end

    shared_examples 'handling upstream update' do
      let(:local_project_id) { local_project&.id }
      let(:local_group_id) { local_group&.id }
      let(:expected_attributes) do
        {
          name: name || upstream.name,
          description: description || upstream.description,
          local_project_id: local_project_id || upstream.local_project_id,
          local_group_id: local_group_id || upstream.local_group_id,
          cache_validity_hours: cache_validity_hours || upstream.cache_validity_hours,
          metadata_cache_validity_hours: metadata_cache_validity_hours || upstream.metadata_cache_validity_hours,
          group_id: registry.group.id
        }
      end

      if params[:error_message]
        it_behaves_like 'returning an error service response', message: params[:error_message]
      else
        it_behaves_like 'updating an upstream'
      end
    end

    subject(:execute) { service.execute }

    context 'for local project upstream' do
      let(:local_project) { other_project }
      let(:local_group) { nil }

      where(:name, :description, :cache_validity_hours, :metadata_cache_validity_hours, :error_message) do
        nil    | nil           | nil | nil | nil
        'name' | 'description' | nil | nil | nil
        'name' | nil           | nil | nil | nil
        'name' | nil           | 2   | nil | nil
        'name' | nil           | nil | 2   | nil
        'name' | nil           | -1  | nil | ["Cache validity hours must be greater than or equal to 0"]
        'name' | nil           | nil | -1  | ["Metadata cache validity hours must be greater than 0"]
      end

      with_them do
        it_behaves_like 'handling upstream update'
      end

      context 'for local private project upstream when the user can not read packages' do
        let_it_be_with_reload(:other_project) { create(:project, :private) }
        let(:params) { { local_project_id: other_project.id } }

        it_behaves_like 'returning an error service response',
          message: described_class::ERRORS[:local_upstream_unauthorized].message

        context 'with the public package registry enabled' do
          let(:expected_attributes) do
            {
              local_project_id: other_project.id,
              group_id: registry.group.id
            }
          end

          before_all do
            other_project.project_feature.update!(package_registry_access_level: ::ProjectFeature::PUBLIC)
          end

          it_behaves_like 'updating an upstream'
        end
      end
    end

    context 'for local group upstream' do
      let_it_be_with_reload(:upstream) do
        create(:virtual_registries_packages_maven_local_upstream, :local_group, registries: [registry], group: group)
      end

      let(:local_group) { other_group }

      # rubocop:disable Layout/LineLength -- splitting the table syntax affects readability
      where(:name, :description, :local_project, :cache_validity_hours, :metadata_cache_validity_hours, :error_message) do
        'name' | nil           | nil                 | nil | nil | nil
        'name' | 'description' | nil                 | nil | nil | nil
        'name' | nil           | nil                 | 2   | nil | nil
        'name' | nil           | nil                 | nil | 2   | nil
        'name' | nil           | ref(:other_project) | nil | nil | ["should only have either the local group or local project set"]
      end
      # rubocop:enable Layout/LineLength

      with_them do
        it_behaves_like 'handling upstream update'
      end

      context 'for local private group upstream when the user can not read packages' do
        let_it_be(:other_group) { create(:group, :private) }
        let(:params) { { local_group_id: other_group.id } }

        it_behaves_like 'returning an error service response',
          message: described_class::ERRORS[:local_upstream_unauthorized].message
      end
    end

    context 'with a non-existing local project' do
      let(:params) { { local_project_id: non_existing_record_id } }

      it_behaves_like 'returning an error service response',
        message: described_class::ERRORS[:local_upstream_unauthorized].message
    end

    context 'with a non-existing local group' do
      let(:params) { { local_group_id: non_existing_record_id } }

      it_behaves_like 'returning an error service response',
        message: described_class::ERRORS[:local_upstream_unauthorized].message
    end

    context 'with all nil params' do
      let(:params) { { name: nil, description: nil } }

      it_behaves_like 'returning an error service response', message: described_class::ERRORS[:empty_params].message
    end

    context 'with unauthorized user' do
      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_local_upstream, registries: [registry]) }

      let(:params) { { name: 'test' } }

      it_behaves_like 'returning an error service response', message: described_class::ERRORS[:unauthorized].message
    end

    context 'with an anonymous user' do
      let(:params) { { name: 'test' } }
      let(:user) { nil }

      it_behaves_like 'returning an error service response', message: described_class::ERRORS[:unauthorized].message
    end
  end
end
