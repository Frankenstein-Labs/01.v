# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::DependenciesResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  before do
    stub_licensed_features(security_dashboard: true, dependency_scanning: true)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, developers: user) }
  let_it_be(:project_1) { create(:project, namespace: namespace) }
  let_it_be(:project_2) { create(:project, namespace: namespace) }

  let_it_be(:component_1) { create(:sbom_component, name: "activestorage") }
  let_it_be(:occurrence_1) { create(:sbom_occurrence, component: component_1, project: project_1) }

  let_it_be(:component_2) { create(:sbom_component, name: "activesupport") }
  let_it_be(:occurrence_2) { create(:sbom_occurrence, component: component_2, project: project_1) }
  let_it_be(:occurrence_3) { create(:sbom_occurrence, component: component_2, project: project_2) }

  let_it_be(:mit_component) { create(:sbom_component, name: "mit-licensed") }
  let_it_be(:occurrence_mit) { create(:sbom_occurrence, :mit, component: mit_component, project: project_1) }

  let_it_be(:apache_component) { create(:sbom_component, name: "apache-licensed") }
  let_it_be(:occurrence_apache) { create(:sbom_occurrence, :apache_2, component: apache_component, project: project_1) }

  subject(:sync_resolve) { sync(resolve_dependencies(args: args)) }

  shared_examples 'supports filtering by component name' do
    let(:args) { { component_names: [component_1.name] } }

    it { is_expected.to match_array([occurrence_1]) }
  end

  shared_examples 'supports filtering by license' do
    context 'when a matching license is given' do
      let(:args) { { licenses: ['MIT'] } }

      it { is_expected.to match_array([occurrence_mit]) }
    end

    context 'when a non-matching license is given' do
      let(:args) { { licenses: ['BSD-3-Clause'] } }

      it { is_expected.to be_empty }
    end
  end

  shared_examples 'supports the malware filter argument' do
    context 'when malicious_packages_dependency_list_filtering feature flag is disabled' do
      before do
        stub_feature_flags(malicious_packages_dependency_list_filtering: false)
      end

      context 'when malware: true is given' do
        let(:args) { { malware: true } }

        it 'returns a GraphQL ArgumentError' do
          expect_graphql_error_to_be_created(
            ::Gitlab::Graphql::Errors::ArgumentError,
            'The malware filter is not available.'
          ) { sync_resolve }
        end
      end

      context 'when malware: false is given' do
        let(:args) { { malware: false } }

        it 'returns a GraphQL ArgumentError' do
          expect_graphql_error_to_be_created(
            ::Gitlab::Graphql::Errors::ArgumentError,
            'The malware filter is not available.'
          ) { sync_resolve }
        end
      end
    end

    context 'when malicious_packages_dependency_list_filtering feature flag is enabled' do
      before do
        stub_feature_flags(malicious_packages_dependency_list_filtering: true)
      end

      context 'when malware: true is given' do
        let(:args) { { malware: true } }

        # The argument is currently a no-op: `mapped_params` strips :malware before reaching the
        # finder, so the resolver returns the unfiltered list. See issue 587758.
        it 'returns the unfiltered dependency list' do
          expect(sync_resolve).to match_array(unfiltered_occurrences)
        end
      end
    end
  end

  context 'when given a project' do
    let(:project_or_namespace) { project_1 }
    let(:unfiltered_occurrences) { [occurrence_1, occurrence_2, occurrence_mit, occurrence_apache] }

    it_behaves_like 'supports filtering by component name'
    it_behaves_like 'supports filtering by license'
    it_behaves_like 'supports the malware filter argument'

    context 'when given component_ids' do
      let(:args) do
        {
          component_ids: [component_1.to_gid]
        }
      end

      it { is_expected.to match_array([occurrence_1]) }

      it "triggers an internal event" do
        expect { sync_resolve }.to trigger_internal_events('called_dependency_api').with(
          user: user,
          project: project_1,
          additional_properties: { label: 'graphql' }
        )
      end
    end
  end

  context 'when given a namespace' do
    let(:project_or_namespace) { namespace }
    let(:unfiltered_occurrences) { [occurrence_1, occurrence_2, occurrence_3, occurrence_mit, occurrence_apache] }

    it_behaves_like 'supports filtering by component name'
    it_behaves_like 'supports filtering by license'
    it_behaves_like 'supports the malware filter argument'

    context 'when given component_ids' do
      let(:args) do
        {
          component_ids: [component_2.to_gid]
        }
      end

      it { is_expected.to match_array([occurrence_2, occurrence_3]) }

      it "triggers an internal event" do
        expect { sync_resolve }.to trigger_internal_events('called_dependency_api').with(
          user: user,
          namespace: namespace,
          additional_properties: { label: 'graphql' }
        )
      end
    end
  end

  describe 'malware N+1 queries (group level)' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project_a) { create(:project, namespace: group) }
    let_it_be(:project_b) { create(:project, namespace: group) }
    let_it_be(:user_with_access) { create(:user) }

    let(:query) do
      %(
        query {
          group(fullPath: "#{group.full_path}") {
            dependencies {
              nodes {
                name
                malware
              }
            }
          }
        }
      )
    end

    before_all do
      group.add_developer(user_with_access)
    end

    before do
      stub_licensed_features(security_dashboard: true, dependency_scanning: true)
    end

    it 'avoids N+1 database queries when fetching malware across group dependencies', :request_store do
      component_1 = create(:sbom_component)
      occurrence_1 = create(:sbom_occurrence, component: component_1, project: project_a)
      vulnerability_1 = create(:vulnerability, :with_finding, project: project_a)
      create(:sbom_occurrences_vulnerability, occurrence: occurrence_1, vulnerability: vulnerability_1)
      vulnerability_1.vulnerability_read.update!(identifier_names: ['CVE-2021-1234'])

      control = ActiveRecord::QueryRecorder.new do
        GitlabSchema.execute(query, context: { current_user: user_with_access })
      end

      # Add more occurrences across multiple projects to verify no N+1
      3.times do
        component = create(:sbom_component)
        occurrence = create(:sbom_occurrence, component: component, project: project_b)
        vulnerability = create(:vulnerability, :with_finding, project: project_b)
        create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability)
        vulnerability.vulnerability_read.update!(identifier_names: ['CVE-2021-1234'])
      end

      expect do
        GitlabSchema.execute(query, context: { current_user: user_with_access })
      end.not_to exceed_query_limit(control)
    end
  end

  private

  def resolve_dependencies(args: {})
    resolve(
      described_class,
      obj: project_or_namespace,
      args: args,
      ctx: { current_user: user }
    )
  end
end
