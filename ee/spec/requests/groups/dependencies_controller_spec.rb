# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::DependenciesController, feature_category: :dependency_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    sign_in(user)
  end

  describe 'GET index' do
    context 'with HTML format' do
      subject(:show_dependency_list) { get group_dependencies_path(group_id: group.full_path) }

      context 'when `dependency_scanning` feature is enabled' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        context 'and user is allowed to access group level dependencies' do
          before do
            group.add_developer(user)
          end

          it 'returns http status :ok' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'pushes the read_advanced_dependency_management ability to the frontend' do
            expect_next_instance_of(described_class) do |controller|
              expect(controller).to receive(:push_frontend_ability).with(
                ability: :read_advanced_dependency_management,
                resource: group,
                user: user
              )
            end

            show_dependency_list
          end

          it 'returns the correct template' do
            subject

            expect(assigns(:group)).to eq(group)
            expect(response).to render_template(:index)
            expect(response.body).to include('data-documentation-path')
            expect(response.body).to include('data-empty-state-svg-path')
            expect(response.body).to include('data-endpoint')
            expect(response.body).to include('data-export-endpoint')
          end

          it_behaves_like 'tracks govern usage event', 'dependencies' do
            let(:request) { show_dependency_list }
          end

          it "triggers an internal event" do
            expect { show_dependency_list }.to trigger_internal_events('visit_dependency_list').with(
              user: user,
              namespace: group
            )
          end

          it "triggers an internal event" do
            expect { get group_dependencies_path(group_id: group.full_path, format: :json) }
              .to trigger_internal_events('called_dependency_api').with(
                user: user,
                namespace: group,
                additional_properties: { label: 'json' }
              )
          end
        end

        context 'when user is not allowed to access group level dependencies' do
          it 'return http status :not_found' do
            subject

            expect(response).to have_gitlab_http_status(:not_found)
          end

          it_behaves_like "doesn't track govern usage event", 'dependencies' do
            let(:request) { subject }
          end

          it 'does not record events or metrics' do
            expect { show_dependency_list }.not_to trigger_internal_events('visit_dependency_list')
          end
        end
      end

      context 'when `dependency_scanning` feature is disabled' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it 'return http status :not_found' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it_behaves_like "doesn't track govern usage event", 'visiting_dependencies' do
          let(:request) { show_dependency_list }
        end

        it 'does not record events or metrics' do
          expect { show_dependency_list }.not_to trigger_internal_events('visit_dependency_list')
        end
      end
    end

    context 'with JSON format' do
      subject { get group_dependencies_path(group_id: group.full_path, format: :json, params: params) }

      let(:params) { {} }

      context 'when `dependency_scanning` is enabled' do
        before do
          stub_licensed_features(dependency_scanning: true, license_scanning: true)
        end

        context 'and user is allowed to access group level dependencies' do
          let(:expected_response) do
            {
              'dependencies' => []
            }
          end

          before do
            group.add_developer(user)
          end

          it 'returns http status :ok' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'returns the expected data' do
            subject

            expect(json_response).to eq(expected_response)
          end

          context 'with existing dependencies' do
            let_it_be(:project) { create(:project, group: group) }
            let_it_be(:component_1) { create(:sbom_component, name: 'activerecord') }
            let_it_be(:component_2) { create(:sbom_component, name: 'apollo') }
            let_it_be_with_reload(:sbom_occurrence_npm) do
              create(
                :sbom_occurrence,
                :mit,
                :npm,
                highest_severity: 'low',
                component: component_1,
                project: project
              )
            end

            let_it_be_with_reload(:sbom_occurrence_bundler) do
              create(
                :sbom_occurrence,
                :apache_2, :bundler,
                highest_severity: 'high',
                component: component_2,
                project: project
              )
            end

            let_it_be(:archived_occurrence) do
              create(:sbom_occurrence, project: create(:project, :archived, group: group))
            end

            let(:expected_response) do
              {
                'dependencies' => [
                  {
                    'name' => sbom_occurrence_npm.name,
                    'packager' => sbom_occurrence_npm.packager,
                    'version' => sbom_occurrence_npm.version,
                    'licenses' => [
                      {
                        'spdx_identifier' => 'MIT',
                        'name' => 'MIT License',
                        'url' => 'https://spdx.org/licenses/MIT.html'
                      }
                    ],
                    'occurrence_count' => 1,
                    'project_count' => 1,
                    "component_id" => sbom_occurrence_npm.component_version_id,
                    "occurrence_id" => sbom_occurrence_npm.id,
                    "vulnerability_count" => 0
                  },
                  {
                    'name' => sbom_occurrence_bundler.name,
                    'packager' => sbom_occurrence_bundler.packager,
                    'version' => sbom_occurrence_bundler.version,
                    'licenses' => [
                      {
                        'spdx_identifier' => 'Apache-2.0',
                        'name' => 'Apache 2.0 License',
                        'url' => 'https://spdx.org/licenses/Apache-2.0.html'
                      }
                    ],
                    'occurrence_count' => 1,
                    'project_count' => 1,
                    "component_id" => sbom_occurrence_bundler.component_version_id,
                    "occurrence_id" => sbom_occurrence_bundler.id,
                    "vulnerability_count" => 0
                  }
                ]
              }
            end

            it 'excludes dependencies from archived projects' do
              subject

              occurrence_ids = json_response['dependencies'].pluck('occurrence_id')
              expect(occurrence_ids).not_to include(archived_occurrence.id)
            end

            it 'returns the expected response' do
              subject

              expect(json_response).to eq(expected_response)
            end

            it 'includes pagination headers in the response' do
              subject

              expect(response.headers).to include('X-Per-Page', 'X-Page', 'X-Next-Page', 'X-Prev-Page')
              expect(response.headers['X-Page-Type']).to eq('cursor')
            end

            it 'includes expected fields in each dependency' do
              subject

              dependency = json_response['dependencies'].first
              expect(dependency.keys).to include(
                'name',
                'packager',
                'version',
                'licenses',
                'occurrence_count',
                'project_count',
                'component_id',
                'occurrence_id',
                'vulnerability_count'
              )
            end

            context 'with policy dismissals' do
              before do
                stub_licensed_features(dependency_scanning: true, license_scanning: true, security_dashboard: true)
              end

              let_it_be(:security_policy) { create(:security_policy) }

              let_it_be(:policy_dismissal) do
                create(:policy_dismissal,
                  :preserved,
                  project: project,
                  security_policy: security_policy,
                  license_occurrence_uuids: [sbom_occurrence_npm.uuid])
              end

              it 'includes policy_dismissals for dependencies with dismissals' do
                subject

                dependencies = json_response['dependencies']
                npm_dep = dependencies.find { |d| d['name'] == sbom_occurrence_npm.name }
                bundler_dep = dependencies.find { |d| d['name'] == sbom_occurrence_bundler.name }

                expect(npm_dep['policy_dismissals'].size).to eq(1)
                expect(npm_dep['policy_dismissals'].first['project_id']).to eq(project.id)
                expect(bundler_dep['policy_dismissals']).to eq([])
              end

              context 'when dismissal spans multiple component versions' do
                let_it_be(:policy_dismissal_both) do
                  create(:policy_dismissal,
                    :preserved,
                    project: project,
                    security_policy: security_policy,
                    license_occurrence_uuids: [sbom_occurrence_npm.uuid, sbom_occurrence_bundler.uuid])
                end

                it 'includes the dismissal for both dependencies' do
                  subject

                  dependencies = json_response['dependencies']
                  npm_dep = dependencies.find { |d| d['name'] == sbom_occurrence_npm.name }
                  bundler_dep = dependencies.find { |d| d['name'] == sbom_occurrence_bundler.name }

                  npm_dismissal_ids = npm_dep['policy_dismissals'].pluck('id')
                  bundler_dismissal_ids = bundler_dep['policy_dismissals'].pluck('id')

                  expect(npm_dismissal_ids).to include(policy_dismissal_both.id)
                  expect(bundler_dismissal_ids).to include(policy_dismissal_both.id)
                end
              end

              context 'with same component across multiple projects' do
                let_it_be(:other_project) { create(:project, group: group) }
                let_it_be(:other_occurrence) do
                  create(
                    :sbom_occurrence,
                    :mit,
                    :npm,
                    component: component_1,
                    component_version: sbom_occurrence_npm.component_version,
                    project: other_project
                  )
                end

                let_it_be(:other_dismissal) do
                  create(:policy_dismissal,
                    :preserved,
                    project: other_project,
                    security_policy: security_policy,
                    license_occurrence_uuids: [other_occurrence.uuid])
                end

                it 'includes dismissals from all projects for the same component' do
                  subject

                  dependencies = json_response['dependencies']
                  npm_dep = dependencies.find { |d| d['name'] == sbom_occurrence_npm.name }

                  dismissal_project_ids = npm_dep['policy_dismissals'].pluck('project_id')
                  expect(dismissal_project_ids).to contain_exactly(project.id, other_project.id)
                end
              end

              context 'when no dismissals match any occurrence UUIDs' do
                let_it_be(:unmatched_dismissal) do
                  create(:policy_dismissal,
                    :preserved,
                    project: project,
                    security_policy: security_policy,
                    license_occurrence_uuids: [SecureRandom.uuid])
                end

                it 'does not include unmatched dismissals' do
                  subject

                  dependencies = json_response['dependencies']
                  bundler_dep = dependencies.find { |d| d['name'] == sbom_occurrence_bundler.name }
                  dismissal_ids = bundler_dep['policy_dismissals'].pluck('id')

                  expect(dismissal_ids).not_to include(unmatched_dismissal.id)
                end
              end

              context 'when dismissal references UUIDs not in the group' do
                let_it_be(:external_uuid) { SecureRandom.uuid }
                let_it_be(:dismissal_with_external_uuid) do
                  create(:policy_dismissal,
                    :preserved,
                    project: project,
                    security_policy: security_policy,
                    license_occurrence_uuids: [external_uuid, sbom_occurrence_npm.uuid])
                end

                it 'ignores unmatched UUIDs and still maps the valid ones' do
                  subject

                  dependencies = json_response['dependencies']
                  npm_dep = dependencies.find { |d| d['name'] == sbom_occurrence_npm.name }
                  dismissal_ids = npm_dep['policy_dismissals'].pluck('id')

                  expect(dismissal_ids).to include(dismissal_with_external_uuid.id)
                end
              end

              context 'when dismissal has multiple UUIDs for the same component version' do
                let_it_be(:second_occurrence_same_cv) do
                  create(
                    :sbom_occurrence,
                    :mit,
                    :npm,
                    component: component_1,
                    component_version: sbom_occurrence_npm.component_version,
                    project: project,
                    source: create(:sbom_source)
                  )
                end

                let_it_be(:dismissal_with_duplicate_cv) do
                  create(:policy_dismissal,
                    :preserved,
                    project: project,
                    security_policy: security_policy,
                    license_occurrence_uuids: [sbom_occurrence_npm.uuid, second_occurrence_same_cv.uuid])
                end

                it 'includes the dismissal only once per component version' do
                  subject

                  dependencies = json_response['dependencies']
                  npm_dep = dependencies.find { |d| d['name'] == sbom_occurrence_npm.name }
                  matching_ids = npm_dep['policy_dismissals'].select { |d| d['id'] == dismissal_with_duplicate_cv.id }

                  expect(matching_ids.size).to eq(1)
                end
              end

              context 'when dependencies have no component_version_ids' do
                before do
                  # rubocop:disable RSpec/AnyInstanceOf -- allow_next_instances_of cannot reliably stub
                  # the loaded results because ActiveRecord instantiates many internal Sbom::Occurrence
                  # objects during query execution, consuming the mock count before reaching the actual
                  # result records.
                  allow_any_instance_of(::Sbom::Occurrence).to receive(:component_version_id).and_return(nil)
                  # rubocop:enable RSpec/AnyInstanceOf
                end

                it 'returns empty policy_dismissals' do
                  subject

                  dependencies = json_response['dependencies']
                  dependencies.each do |dep|
                    expect(dep['policy_dismissals']).to eq([])
                  end
                end
              end

              context 'when uuid lookup returns empty results' do
                before do
                  allow_next_instance_of(::Preloaders::Sbom::PolicyDismissalsPreloader) do |preloader|
                    allow(preloader).to receive(:execute)
                  end
                end

                it 'returns empty policy_dismissals' do
                  subject

                  dependencies = json_response['dependencies']
                  dependencies.each do |dep|
                    expect(dep['policy_dismissals']).to eq([])
                  end
                end
              end

              context 'when user does not have read_security_resource permission' do
                before do
                  stub_licensed_features(dependency_scanning: true, license_scanning: true, security_dashboard: false)
                end

                it 'does not include policy_dismissals in response' do
                  subject

                  dependencies = json_response['dependencies']
                  dependencies.each do |dep|
                    expect(dep).not_to have_key('policy_dismissals')
                  end
                end
              end
            end

            context 'with dependencies from subgroups' do
              let_it_be(:subgroup) { create(:group, parent: group) }
              let_it_be(:subgroup_project) { create(:project, group: subgroup) }
              let_it_be(:subgroup_occurrence) do
                create(:sbom_occurrence, :mit, :yarn, project: subgroup_project)
              end

              it 'includes dependencies from subgroup projects' do
                subject

                expect(response).to have_gitlab_http_status(:ok)
                occurrence_ids = json_response['dependencies'].pluck('occurrence_id')
                expect(occurrence_ids).to include(subgroup_occurrence.id)
              end
            end

            context 'when filtering with component_id' do
              let(:params) do
                {
                  component_ids: [component_1.id]
                }
              end

              it 'returns matching Sbom::Occurrence records' do
                subject

                dependency_name = json_response.dig("dependencies", 0, "name")

                expect(dependency_name).to eq(sbom_occurrence_npm.component_name)
              end
            end

            context 'when filtering with component_names' do
              let(:params) do
                {
                  component_names: [component_1.name]
                }
              end

              it 'returns matching Sbom::Occurrence records' do
                subject

                dependency_name = json_response.dig("dependencies", 0, "name")

                expect(dependency_name).to eq(sbom_occurrence_npm.component_name)
              end
            end

            context 'when paginating over licenses' do
              let(:params) do
                {
                  group_id: group.to_param,
                  sort_by: 'license',
                  sort: 'asc',
                  per_page: 1
                }
              end

              it 'uses primary_license_spdx_identifier in the cursor' do
                subject

                cursor = response.headers['X-Next-Page']
                data = Gitlab::Json.parse(Base64.urlsafe_decode64(cursor))

                expect(data['primary_license_spdx_identifier']).to eq('Apache-2.0')
              end
            end

            context 'when using a cursor' do
              let(:cursor_data) do
                { highest_severity: sbom_occurrence_npm.highest_severity,
                  component_id: sbom_occurrence_npm.component_id,
                  component_version_id: sbom_occurrence_npm.component_version_id }
              end

              let(:cursor) { Base64.urlsafe_encode64(cursor_data.to_json) }
              let(:params) { { group_id: group.to_param, cursor: cursor, sort_by: 'severity', sort: 'asc' } }

              it 'returns data at the cursor' do
                subject

                dependencies = json_response['dependencies']

                expect(dependencies.size).to eq(1)
                expect(dependencies.first['name']).to eq(sbom_occurrence_bundler.name)
              end

              context 'when cursor contains nulls' do
                before_all do
                  sbom_occurrence_bundler.update!(highest_severity: nil)
                  sbom_occurrence_npm.update!(highest_severity: nil)
                end

                it 'returns data at the cursor' do
                  subject

                  dependencies = json_response['dependencies']

                  expect(dependencies.size).to eq(1)
                  expect(dependencies.first['name']).to eq(sbom_occurrence_bundler.name)
                end
              end
            end

            it 'avoids N+1 database queries', :aggregate_failures do
              recording = ActiveRecord::QueryRecorder.new { subject }

              expect(recording).not_to exceed_all_query_limit(1).allow_skip_cache_inconsistency.for_model(::Sbom::Component)
              expect(recording).not_to exceed_all_query_limit(1).allow_skip_cache_inconsistency.for_model(::Sbom::ComponentVersion)
              expect(recording).not_to exceed_all_query_limit(1).allow_skip_cache_inconsistency.for_model(::Sbom::Source)
            end

            context 'when sorted by license in ascending order' do
              let(:params) { { group_id: group.to_param, sort_by: 'license', sort: 'asc' } }

              it 'returns sorted list' do
                subject

                expect(json_response['dependencies'].first['licenses'].first['spdx_identifier']).to eq('Apache-2.0')
                expect(json_response['dependencies'].last['licenses'].first['spdx_identifier']).to eq('MIT')
              end
            end

            context 'when sorted by license in descending order' do
              let(:params) { { group_id: group.to_param, sort_by: 'license', sort: 'desc' } }

              it 'returns sorted list' do
                subject

                expect(json_response['dependencies'].first['licenses'].first['spdx_identifier']).to eq('MIT')
                expect(json_response['dependencies'].last['licenses'].first['spdx_identifier']).to eq('Apache-2.0')
              end
            end

            context 'when sorted by name in ascending order' do
              let(:params) { { group_id: group.to_param, sort_by: 'name', sort: 'asc' } }

              it 'returns sorted list' do
                subject

                expect(json_response['dependencies'].first['name']).to eq(sbom_occurrence_npm.name)
                expect(json_response['dependencies'].last['name']).to eq(sbom_occurrence_bundler.name)
              end
            end

            context 'when sorted by name in descending order' do
              let(:params) { { group_id: group.to_param, sort_by: 'name', sort: 'desc' } }

              it 'returns sorted list' do
                subject

                expect(json_response['dependencies'].first['name']).to eq(sbom_occurrence_bundler.name)
                expect(json_response['dependencies'].last['name']).to eq(sbom_occurrence_npm.name)
              end
            end

            context 'when sorted by packager in ascending order' do
              let(:params) { { group_id: group.to_param, sort_by: 'packager', sort: 'asc' } }

              it 'returns sorted list' do
                subject

                expect(json_response['dependencies'].first['name']).to eq(sbom_occurrence_bundler.name)
                expect(json_response['dependencies'].last['name']).to eq(sbom_occurrence_npm.name)
              end
            end

            context 'when sorted by packager in descending order' do
              let(:params) { { group_id: group.to_param, sort_by: 'packager', sort: 'desc' } }

              it 'returns sorted list' do
                subject

                expect(json_response['dependencies'].first['name']).to eq(sbom_occurrence_npm.name)
                expect(json_response['dependencies'].last['name']).to eq(sbom_occurrence_bundler.name)
              end
            end

            context 'when sorted by severity in ascending order' do
              let(:params) { { group_id: group.to_param, sort_by: 'severity', sort: 'asc' } }

              it 'returns sorted list' do
                subject

                expect(json_response['dependencies'].first['name']).to eq(sbom_occurrence_npm.name)
                expect(json_response['dependencies'].last['name']).to eq(sbom_occurrence_bundler.name)
              end
            end

            context 'when sorted by severity in descending order' do
              let(:params) { { group_id: group.to_param, sort_by: 'severity', sort: 'desc' } }

              it 'returns sorted list' do
                subject

                expect(json_response['dependencies'].first['name']).to eq(sbom_occurrence_bundler.name)
                expect(json_response['dependencies'].last['name']).to eq(sbom_occurrence_npm.name)
              end
            end

            context 'with filtering params' do
              context 'when the group hierarchy depth is too high' do
                before do
                  stub_const('::Groups::DependenciesController::GROUP_COUNT_LIMIT', 0)
                end

                it 'ignores the filter' do
                  subject

                  expect(json_response['dependencies'].pluck('name')).to match_array([
                    sbom_occurrence_bundler.component_name,
                    sbom_occurrence_npm.component_name
                  ])
                end
              end

              context 'when filtered by projects' do
                let_it_be(:other_project) { create(:project, group: group) }
                let_it_be(:occurrence_from_other_project) { create(:sbom_occurrence, project: other_project) }

                let(:params) { { project_ids: [other_project.id] } }

                it 'returns a filtered list' do
                  subject

                  expect(json_response['dependencies'].count).to eq(1)
                  expect(json_response['dependencies'].pluck('name')).to eq([occurrence_from_other_project.name])
                end
              end

              context 'when filtered by licenses' do
                let(:params) do
                  {
                    group_id: group.to_param,
                    licenses: ['Apache-2.0']
                  }
                end

                it 'returns a filtered list' do
                  subject

                  expect(json_response['dependencies'].count).to eq(1)
                  expect(json_response['dependencies'].pluck('name')).to eq([sbom_occurrence_bundler.name])
                end
              end

              context 'when filtered by unknown licenses' do
                let_it_be(:sbom_occurrence_unknown) { create(:sbom_occurrence, :unknown, project: project) }

                let(:params) do
                  {
                    group_id: group.to_param,
                    licenses: ['unknown']
                  }
                end

                it 'returns a filtered list' do
                  subject

                  expect(json_response['dependencies'].pluck('occurrence_id')).to eq([sbom_occurrence_unknown.id])
                end
              end

              context 'when filtered by multiple licenses' do
                let_it_be(:sbom_occurrence_unknown) { create(:sbom_occurrence, :unknown, project: project) }

                let(:params) do
                  {
                    group_id: group.to_param,
                    licenses: ['Apache-2.0', 'unknown']
                  }
                end

                it 'returns a filtered list' do
                  subject

                  expect(json_response['dependencies'].pluck('occurrence_id')).to match_array([
                    sbom_occurrence_bundler.id, sbom_occurrence_unknown.id
                  ])
                end
              end

              context 'when trying to search for too many projects' do
                let(:params) { { project_ids: (1..11).to_a } }

                it 'returns an error' do
                  subject

                  expect(response).to have_gitlab_http_status(:unprocessable_entity)
                  expect(json_response['message']).to eq(
                    format(
                      _('A maximum of %{limit} projects can be searched for at one time.'),
                      limit: described_class::PROJECT_IDS_LIMIT
                    )
                  )
                end
              end

              context 'when filtered by component_versions without component_names' do
                let(:params) do
                  {
                    group_id: group.to_param,
                    component_versions: [sbom_occurrence_bundler.component_version.version]
                  }
                end

                it 'returns an error' do
                  subject

                  expect(response).to have_gitlab_http_status(:unprocessable_entity)
                  expect(json_response['message']).to eq(
                    format(
                      _('Single component can be selected for component filter to be able to filter by version.')
                    )
                  )
                end
              end

              context 'when negated filtered by component_versions without component_names' do
                let(:params) do
                  {
                    group_id: group.to_param,
                    not: { component_versions: [sbom_occurrence_bundler.component_version.version] }
                  }
                end

                it 'returns an error' do
                  subject

                  expect(response).to have_gitlab_http_status(:unprocessable_entity)
                  expect(json_response['message']).to eq(
                    format(
                      _('Single component can be selected for component filter to be able to filter by version.')
                    )
                  )
                end
              end

              context 'when filtered by component_versions' do
                let(:params) do
                  {
                    group_id: group.to_param,
                    component_names: [component_2.name],
                    component_versions: [sbom_occurrence_bundler.component_version.version]
                  }
                end

                it "triggers an internal event" do
                  expect { subject }.to trigger_internal_events('filter_dependency_list_by_version').with(
                    user: user,
                    namespace: group
                  ).and increment_usage_metrics('counts.count_total_filter_dependency_list_by_version')
                end

                it 'returns a filtered list' do
                  subject

                  expect(json_response['dependencies'].pluck('occurrence_id')).to match_array([
                    sbom_occurrence_bundler.id
                  ])
                end
              end

              context 'when filtered by negated component_versions' do
                let(:params) do
                  {
                    group_id: group.to_param,
                    component_names: [component_2.name],
                    not: { component_versions: [sbom_occurrence_bundler.component_version.version] }
                  }
                end

                it "triggers an internal event" do
                  expect { subject }.to trigger_internal_events('filter_dependency_list_by_version').with(
                    user: user,
                    namespace: group
                  ).and increment_usage_metrics('counts.count_total_filter_dependency_list_by_version')
                end

                it 'returns a filtered list' do
                  subject

                  expect(json_response['dependencies'].pluck('occurrence_id')).to be_empty
                end
              end
            end
          end
        end

        context 'when user is not allowed to access group level dependencies' do
          it 'returns http status :forbidden' do
            subject

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end

      context 'when `dependency_scanning` feature is disabled' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it 'returns http status :forbidden' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe 'GET locations' do
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:component_version) { create(:sbom_component_version) }
    let(:params) { { group_id: group.to_param, search: 'file', component_id: component_version.id } }

    subject { get locations_group_dependencies_path(group_id: group.full_path), params: params, as: :json }

    context 'when `dependency_scanning` feature is enabled' do
      before do
        stub_licensed_features(dependency_scanning: true)
      end

      context 'and user is allowed to access group level dependencies' do
        before do
          group.add_developer(user)
        end

        it 'returns http status :ok' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'returns empty array' do
          subject

          expect(json_response['locations']).to be_empty
        end

        context 'with existing matches' do
          let_it_be(:occurrence_npm) do
            create(:sbom_occurrence, component_version: component_version, project: project)
          end

          let_it_be(:source_npm) { occurrence_npm.source }
          let_it_be(:source_bundler) { create(:sbom_source, packager_name: 'bundler', input_file_path: 'Gemfile.lock') }
          let_it_be(:occurrence_bundler) do
            create(:sbom_occurrence, source: source_bundler, component_version: component_version, project: project)
          end

          let_it_be(:location_bundler) { occurrence_bundler.location }

          let(:expected_response) do
            [
              {
                'location' => {
                  "blob_path" => location_bundler[:blob_path],
                  "path" => location_bundler[:path],
                  "top_level" => location_bundler[:top_level]
                },
                "has_dependency_paths" => false,
                'project' => {
                  "name" => project.name,
                  "full_path" => project.full_path
                },
                'occurrence_id' => occurrence_bundler.id
              }
            ]
          end

          it 'returns location related data' do
            subject

            expect(json_response['locations']).to eq(expected_response)
          end

          context 'without filtering params' do
            let(:params) { { group_id: group.to_param } }

            it 'returns empty array' do
              subject

              expect(json_response['locations']).to be_empty
            end
          end
        end
      end

      context 'when user is not allowed to access group level dependencies' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it 'returns http status :forbidden' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when `dependency_scanning` feature is disabled' do
      it 'returns http status :forbidden' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET #licenses' do
    let_it_be(:project) { create(:project, namespace: group) }

    subject(:get_licenses) { get licenses_group_dependencies_path(group_id: group.full_path), as: :json }

    context 'when `license_scanning` feature is enabled' do
      before do
        stub_licensed_features(dependency_scanning: true, license_scanning: true)
      end

      context 'and user is allowed to access group level dependencies' do
        before do
          group.add_developer(user)
        end

        it 'returns http status :ok' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'returns licenses from Gitlab::SPDX::Catalogue sorted by name' do
          expect(Gitlab::SPDX::Catalogue).to receive(:latest_licenses).and_call_original

          subject

          expect(json_response['licenses']).not_to be_empty
          license_names = json_response['licenses'].pluck('name')
          expect(license_names.sort).to eq(license_names)
        end
      end

      context 'when user is not allowed to access group level dependencies' do
        it 'returns http status :forbidden' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when `license_scanning` feature is disabled' do
      before do
        stub_licensed_features(license_scanning: false)
      end

      it 'returns http status :forbidden' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
