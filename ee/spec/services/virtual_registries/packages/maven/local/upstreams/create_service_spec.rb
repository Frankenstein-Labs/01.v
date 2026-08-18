# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Local::Upstreams::CreateService, :aggregate_failures, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group:) }

  let(:service) { described_class.new(registry: registry, current_user: user, params: params) }
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
    let_it_be(:other_project) { create(:project, owners: [user]) }
    let_it_be(:other_group) { create(:group, owners: [user]) }

    shared_examples 'creating an upstream' do
      it 'creates an upstream entry successfully' do
        expect { execute }.to change { ::VirtualRegistries::Packages::Maven::Local::Upstream.count }.from(0).to(1)
          .and change { registry.registry_upstreams.count }.from(0).to(1)
        expect(execute).to be_success
        expect(execute.payload).to have_attributes(expected_attributes)
      end
    end

    subject(:execute) { service.execute }

    # rubocop:disable Layout/LineLength -- splitting the table syntax affects readability
    where(:name, :description, :local_project, :local_group, :cache_validity_hours, :metadata_cache_validity_hours, :error_message) do
      'name' | nil | ref(:other_project) | nil | nil | nil | nil
      'name' | 'description' | ref(:other_project) | nil | nil | nil | nil
      'name' | nil | ref(:other_project) | nil | 2 | nil | nil
      'name' | nil | ref(:other_project) | nil | nil | 2 | nil

      nil | nil | ref(:other_project) | nil | nil | nil | ["Name can't be blank"]
      'name' | nil | ref(:other_project) | nil | -1 | nil | ["Cache validity hours must be greater than or equal to 0"]
      'name' | nil | ref(:other_project) | nil | nil | -1 | ["Metadata cache validity hours must be greater than 0"]

      'name' | nil | nil | ref(:other_group) | nil | nil | nil
      'name' | 'description' | nil | ref(:other_group) | nil | nil | nil
      'name' | nil | nil | ref(:other_group) | 2 | nil | nil
      'name' | nil | nil | ref(:other_group) | nil | 2 | nil

      'name' | nil | ref(:other_project) | ref(:other_group) | nil | nil | ["should only have either the local group or local project set"]
    end
    # rubocop:enable Layout/LineLength

    with_them do
      let(:local_project_id) { local_project&.id }
      let(:local_group_id) { local_group&.id }
      let(:expected_metadata_cache_validity_hours) do
        metadata_cache_validity_hours ||
          ::VirtualRegistries::Packages::Maven::Local::Upstream.new.metadata_cache_validity_hours
      end

      let(:expected_cache_validity_hours) do
        cache_validity_hours || ::VirtualRegistries::Packages::Maven::Local::Upstream.new.cache_validity_hours
      end

      let(:expected_attributes) do
        {
          name: name,
          description: description,
          local_project_id: local_project_id,
          local_group_id: local_group_id,
          cache_validity_hours: expected_cache_validity_hours,
          metadata_cache_validity_hours: expected_metadata_cache_validity_hours,
          group_id: registry.group.id
        }
      end

      if params[:error_message]
        it_behaves_like 'returning an error service response', message: params[:error_message]
      else
        it_behaves_like 'creating an upstream'
      end
    end

    context 'for local private project upstream when the user can not read packages' do
      let_it_be_with_reload(:project) { create(:project, :private) }

      let(:params) { { local_project_id: project.id, name: 'test' } }

      it_behaves_like 'returning an error service response',
        message: described_class::ERRORS[:local_upstream_unauthorized].message

      context 'with a private project and a public package registry' do
        let(:expected_attributes) do
          {
            name: 'test',
            local_project_id: project.id,
            group_id: registry.group.id
          }
        end

        before_all do
          project.project_feature.update!(package_registry_access_level: ::ProjectFeature::PUBLIC)
        end

        it_behaves_like 'creating an upstream'
      end
    end

    context 'for local private group upstream' do
      context 'when the user can not read packages' do
        let_it_be(:group) { create(:group, :private) }
        let(:params) { { local_group_id: group.id, name: 'test' } }

        it_behaves_like 'returning an error service response',
          message: described_class::ERRORS[:local_upstream_unauthorized].message
      end
    end

    context 'with a non-existing local project' do
      let(:params) { { name: 'test', local_project_id: non_existing_record_id } }

      it_behaves_like 'returning an error service response',
        message: described_class::ERRORS[:local_upstream_unauthorized].message
    end

    context 'with a non-existing local group' do
      let(:params) { { name: 'test', local_group_id: non_existing_record_id } }

      it_behaves_like 'returning an error service response',
        message: described_class::ERRORS[:local_upstream_unauthorized].message
    end

    context 'with all nil params' do
      let(:params) { { name: nil, description: nil } }

      it_behaves_like 'returning an error service response', message: described_class::ERRORS[:empty_params].message
    end

    context 'with unauthorized user' do
      let(:params) { { name: 'foo', local_project_id: 1 } }
      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry) }

      it_behaves_like 'returning an error service response', message: described_class::ERRORS[:unauthorized].message
    end

    context 'with an anonymous user' do
      let(:params) { { name: 'foo', local_project_id: 1 } }
      let(:user) { nil }

      it_behaves_like 'returning an error service response', message: described_class::ERRORS[:unauthorized].message
    end
  end
end
