# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying maven upstream registries for top-level group', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group, name: 'test registry') }
  let_it_be(:upstream) do
    create(:virtual_registries_packages_maven_upstream, registries: [registry], name: 'test upstream')
  end

  let(:full_path) { group.full_path }
  let(:upstream_name) { 'test' }
  let(:query) do
    <<~GRAPHQL
      {
        group(fullPath: "#{full_path}") {
          virtualRegistriesPackagesMavenUpstreams(upstreamName: "#{upstream_name}") {
            count
            nodes {
              id
              name
              username
              registriesCount
              rulesCount
            }
          }
        }
      }
    GRAPHQL
  end

  let(:maven_upstreams_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['group']['virtualRegistriesPackagesMavenUpstreams']
  end

  let(:user_has_access) { false }
  let(:feature_enabled) { false }

  let_it_be(:upstream_rule1) do
    create(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream, rule_type: :allow)
  end

  let_it_be(:upstream_rule2) do
    create(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream, rule_type: :deny)
  end

  shared_examples 'returns null for virtualRegistriesPackagesMavenUpstreams' do
    it 'returns null for the virtualRegistriesPackagesMavenUpstreams field' do
      expect(maven_upstreams_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Packages::Maven).to receive_messages(
      user_has_access?: user_has_access,
      feature_enabled?: feature_enabled
    )
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for virtualRegistriesPackagesMavenUpstreams'
  end

  context 'when user has access' do
    let(:user_has_access) { true }

    before_all do
      group.add_guest(current_user)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for virtualRegistriesPackagesMavenUpstreams'
    end

    context 'when virtual registry is available' do
      let(:feature_enabled) { true }

      it 'returns upstream for the virtualRegistriesPackagesMavenUpstreams field' do
        expect(maven_upstreams_response['nodes'][0]['name']).to eq('test upstream')
      end

      it 'returns registries count for each upstream in virtualRegistriesPackagesMavenUpstreams field' do
        expect(maven_upstreams_response['nodes'][0]['registriesCount']).to eq(1)
      end

      it 'returns rules count for each upstream in virtualRegistriesPackagesMavenUpstreams field' do
        expect(maven_upstreams_response['nodes'][0]['rulesCount']).to eq(2)
      end

      it 'returns count for the virtualRegistriesPackagesMavenUpstreams field' do
        expect(maven_upstreams_response['count']).to eq(1)
      end

      context 'with username field authorization' do
        it 'returns null for a guest' do
          expect(maven_upstreams_response['nodes']).to all(include('username' => nil))
        end

        context 'when user is a maintainer' do
          before_all do
            group.add_maintainer(current_user)
          end

          it 'returns the username' do
            expect(maven_upstreams_response['nodes']).to contain_exactly(
              hash_including('username' => upstream.username)
            )
          end
        end
      end

      context 'when upstream name search does not return any value' do
        let(:upstream_name) { 'non existing' }

        it 'returns count 0 for the virtualRegistriesPackagesMavenUpstreams field' do
          expect(maven_upstreams_response['count']).to eq(0)
          expect(maven_upstreams_response['nodes'].size).to eq(0)
        end
      end

      context 'when multiple upstreams and registries exist' do
        let_it_be(:first_user) { create(:user) }
        let_it_be(:second_user) { create(:user) }
        let(:query) do
          <<~GRAPHQL
            {
              group(fullPath: "#{full_path}") {
                virtualRegistriesPackagesMavenUpstreams {
                  count
                  nodes {
                    id
                    name
                    registriesCount
                    rulesCount
                  }
                }
              }
            }
          GRAPHQL
        end

        before_all do
          group.add_guest(first_user)
          group.add_guest(second_user)
        end

        it 'avoids N+1 queries with multiple upstreams and rules' do
          control_count = ActiveRecord::QueryRecorder.new do
            post_graphql(query, current_user: first_user)
          end

          registry1 = create(:virtual_registries_packages_maven_registry, group: group, name: 'test registry1')
          upstream1 = create(:virtual_registries_packages_maven_upstream, registries: [registry, registry1],
            name: 'test upstream1')
          create(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream1, rule_type: :allow)
          create(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream1, rule_type: :deny)
          create(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream1, rule_type: :allow)

          # Unscoped check covers registries_count (batched via registry_upstreams table).
          expect do
            post_graphql(query, current_user: second_user)
          end.not_to exceed_query_limit(control_count)
          expect_graphql_errors_to_be_empty

          # Scoped check is needed for rules_count: the unscoped check is fooled by
          # QueryDiff#reject_groups_with_different_parameters, which cancels out the
          # extra COUNT query as "same query, different parameters" when going from 1
          # to 2 upstreams (each with a distinct remote_upstream_id in the WHERE clause).
          expect do
            post_graphql(query, current_user: second_user)
          end.not_to exceed_query_limit(control_count)
            .for_model(::VirtualRegistries::Packages::Maven::Upstream::Rule)
        end
      end
    end
  end
end
