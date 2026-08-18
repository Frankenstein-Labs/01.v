# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying a maven upstream registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group, name: 'test registry') }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let_it_be_with_reload(:cache_entries) do
    create_list(:virtual_registries_packages_maven_cache_remote_entry, 5, upstream:)
  end

  let_it_be(:upstream_rule1) do
    create(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream, rule_type: :allow)
  end

  let_it_be(:upstream_rule2) do
    create(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream, rule_type: :deny)
  end

  let(:global_id) { upstream.to_gid }
  let(:query) do
    <<~GRAPHQL
      {
        virtualRegistriesPackagesMavenUpstream(id: "#{global_id}") {
          id
          name
          username
          registriesCount
          rulesCount
          allowRules {
            id
            pattern
            patternType
            targetCoordinate
            createdAt
          }
          denyRules {
            id
            pattern
            patternType
            targetCoordinate
            createdAt
          }
          registryUpstreams {
            id
            registry {
              name
            }
          }
          cacheEntries {
            count
            nodes {
              id
            }
          }
        }
      }
    GRAPHQL
  end

  let(:maven_upstream_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['virtualRegistriesPackagesMavenUpstream']
  end

  let(:virtual_registry_available) { false }

  shared_examples 'returns null for virtualRegistriesPackagesMavenUpstream' do
    it 'returns null for the virtualRegistriesPackagesMavenUpstream field' do
      expect(maven_upstream_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for virtualRegistriesPackagesMavenUpstream'
  end

  context 'when user has access' do
    before_all do
      group.add_guest(current_user)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for virtualRegistriesPackagesMavenUpstream'
    end

    context 'when virtual registry is available' do
      let(:virtual_registry_available) { true }

      context 'when upstream exists' do
        it 'returns upstream for the virtualRegistriesPackagesMavenUpstream field' do
          expect(maven_upstream_response['name']).to eq('name')
        end

        it 'returns registries count for the virtualRegistriesPackagesMavenUpstream field' do
          expect(maven_upstream_response['registriesCount']).to eq(1)
        end

        it 'returns registries for the virtualRegistriesPackagesMavenUpstream field' do
          expect(maven_upstream_response['registryUpstreams'][0]['registry']['name']).to eq('test registry')
        end

        it 'returns cache entries and count for the virtualRegistriesPackagesMavenUpstream field' do
          expect(maven_upstream_response['cacheEntries']['count']).to eq(5)
          expect(maven_upstream_response['cacheEntries']['nodes'][0]['id']).to eq(cache_entries.last.generate_id)
        end

        it 'returns rules count for the virtualRegistriesPackagesMavenUpstream field' do
          expect(maven_upstream_response['rulesCount']).to eq(2)
          expect(maven_upstream_response['allowRules'].length).to eq(1)
          expect(maven_upstream_response['denyRules'].length).to eq(1)

          allow_rules = maven_upstream_response['allowRules']
          deny_rules = maven_upstream_response['denyRules']

          expect(allow_rules.first).to include({
            'pattern' => upstream_rule1.pattern,
            'patternType' => upstream_rule1.pattern_type.upcase,
            'targetCoordinate' => upstream_rule1.target_coordinate.upcase
          })

          expect(deny_rules.first).to include({
            'pattern' => upstream_rule2.pattern,
            'patternType' => upstream_rule2.pattern_type.upcase,
            'targetCoordinate' => upstream_rule2.target_coordinate.upcase
          })
        end

        context 'when multiple registries exist' do
          let_it_be(:first_user) { create(:user) }
          let_it_be(:second_user) { create(:user) }

          before_all do
            group.add_guest(first_user)
            group.add_guest(second_user)
          end

          it 'avoids N+1 queries with multiple registries and rules' do
            control_count = ActiveRecord::QueryRecorder.new do
              post_graphql(query, current_user: first_user)
            end

            # Create additional registries
            create(:virtual_registries_packages_maven_registry, group: upstream.group, name: 'other').tap do |registry|
              create(:virtual_registries_packages_maven_registry_upstream, registry:, upstream:)
            end

            create(:virtual_registries_packages_maven_registry, group: upstream.group, name: 'test').tap do |registry|
              create(:virtual_registries_packages_maven_registry_upstream, registry:, upstream:)
            end

            # Create additional rules
            create(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream, rule_type: :allow)

            expect do
              post_graphql(query, current_user: second_user)
            end.not_to exceed_query_limit(control_count)
            expect_graphql_errors_to_be_empty
          end
        end
      end

      context 'when upstream does not exist' do
        let(:global_id) { "gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/#{non_existing_record_id}" }

        it_behaves_like 'returns null for virtualRegistriesPackagesMavenUpstream'
      end

      context 'with username field authorization' do
        context 'when user is a guest' do
          it 'returns null for the username field' do
            expect(maven_upstream_response['username']).to be_nil
          end
        end

        context 'when user is a maintainer' do
          before_all do
            group.add_maintainer(current_user)
          end

          it 'returns the username field' do
            post_graphql(query, current_user: current_user)

            expect(graphql_data['virtualRegistriesPackagesMavenUpstream']['username']).to eq('user')
          end
        end
      end
    end
  end
end
