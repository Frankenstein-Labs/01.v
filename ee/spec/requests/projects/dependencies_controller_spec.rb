# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::DependenciesController, feature_category: :dependency_management do
  let_it_be_with_reload(:developer) { create(:user) }
  let_it_be_with_reload(:guest) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository, :private) }
  let(:params) { {} }

  before_all do
    project.add_developer(developer)
    project.add_guest(guest)
  end

  before do
    sign_in(user)
  end

  describe 'GET #index' do
    subject(:show_dependency_list) { get project_dependencies_path(project) }

    include_context '"Security and compliance" permissions' do
      let(:user) { developer }
      let(:valid_request) { get project_dependencies_path(project) }
    end

    context 'with authorized user' do
      let(:user) { developer }

      context 'when feature is available' do
        before do
          stub_licensed_features(dependency_scanning: true, license_scanning: true, security_dashboard: true)
        end

        context 'when project has sbom_occurrences' do
          let_it_be_with_reload(:registry_occurrence) do
            create(:sbom_occurrence, :registry_occurrence, project: project)
          end

          # `freeze: false` is kept here because this `let_it_be` subject is not an
          # ActiveRecord record, so freezing gives no cross-example isolation benefit
          # and `let_it_be_with_reload`/`refind` are no-ops on it. Keep as-is (see
          # gitlab-org/gitlab#602925).
          let_it_be(:occurrences, freeze: false) do
            [
              create(:sbom_occurrence, :apache_2, :bundler, highest_severity: :critical, project: project),
              create(:sbom_occurrence, :mit, :npm, highest_severity: :high, project: project),
              create(:sbom_occurrence, :mpl_2, :yarn, highest_severity: :low, project: project),
              create(:sbom_occurrence, :license_without_spdx_id, :nuget, highest_severity: nil, project: project)
            ]
          end

          let_it_be_with_reload(:unfiltered_results) do
            # DEFAULT_SOURCES does not include registry sources
            project.sbom_occurrences.where.not(id: registry_occurrence.id)
          end

          before do
            get project_dependencies_path(project, **params, format: :json)
          end

          it 'returns data based on sbom occurrences' do
            expected = unfiltered_results.map do |occurrence|
              {
                'occurrence_id' => occurrence.id,
                'vulnerability_count' => occurrence.vulnerability_count,
                'name' => occurrence.name,
                'packager' => occurrence.packager,
                'version' => occurrence.version,
                'location' => occurrence.location,
                'licenses' => occurrence.licenses,
                'has_dependency_paths' => false,
                'malware' => false
              }.deep_stringify_keys
            end

            expect(json_response['dependencies']).to match_array(expected)
          end

          it 'avoids N+1 queries' do
            control_count = ActiveRecord::QueryRecorder
              .new { get project_dependencies_path(project, **params, format: :json) }.count
            create_list(:sbom_occurrence, 2, project: project)

            expect { get project_dependencies_path(project, **params, format: :json) }
              .not_to exceed_query_limit(control_count)
          end

          shared_examples 'it can filter dependencies' do |filter_under_test|
            subject(:show_dependency_list) { json_response['dependencies'].map(&matcher) }

            let(:matcher) { ->(d) { d['occurrence_id'] } }
            let(:unfiltered_result_ids) { unfiltered_results.map(&:id) }
            let(:params) { { filter_under_test => filter_value } }

            context 'when the filter has a valid param' do
              it { is_expected.to match_array(expected_results.map(&:id)) }
            end

            context 'when the filter is blank' do
              let(:params) { super().transform_values { [] } }

              it { is_expected.to match_array(unfiltered_result_ids) }
            end

            context 'when the filter has invalid input' do
              let(:params) { super().transform_values { nil } }

              it { is_expected.to match_array(unfiltered_result_ids) }
            end
          end

          context 'with component name filter' do
            it_behaves_like 'it can filter dependencies', :component_names do
              let(:filter_value) { [occurrences.last.name] }
              let(:expected_results) { [occurrences.last] }
            end
          end

          context 'with source types filter' do
            it_behaves_like 'it can filter dependencies', :source_types do
              let(:filter_value) { [:container_scanning_for_registry] }
              let(:expected_results) { [registry_occurrence] }
            end
          end

          context 'with license types filter' do
            it_behaves_like 'it can filter dependencies', :licenses do
              let(:filter_value) { ['Apache-2.0'] }
              let(:expected_results) { [occurrences[0]] }
            end
          end

          context 'with packager filter' do
            it_behaves_like 'it can filter dependencies', :package_managers do
              let(:filter_value) { ['nuget'] }
              let(:expected_results) { [occurrences[3]] }
            end
          end

          context 'with component_versions filter' do
            context 'when filtered by component_versions without component_names' do
              let(:params) do
                {
                  component_versions: [occurrences.first.component_version.version]
                }
              end

              it 'returns an error' do
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
                  not: { component_versions: [occurrences.first.component_version.version] }
                }
              end

              it 'returns an error' do
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
                  component_names: [occurrences.last.component.name],
                  component_versions: [occurrences.last.component_version.version]
                }
              end

              it 'tracks filter_dependency_list_by_version action' do
                expect { get project_dependencies_path(project, **params, format: :json) }.to trigger_internal_events(
                  'filter_dependency_list_by_version').with(
                    user: user,
                    project: project
                  ).and increment_usage_metrics('counts.count_total_filter_dependency_list_by_version')
              end
            end

            it_behaves_like 'it can filter dependencies' do
              let(:expected_results) { [occurrences.last] }

              let(:params) do
                {
                  component_names: [occurrences.last.component.name],
                  component_versions: [occurrences.last.component_version.version]
                }
              end
            end

            it_behaves_like 'it can filter dependencies' do
              let(:params) do
                {
                  component_names: [occurrences.last.component.name],
                  not: { component_versions: [occurrences.last.component_version.version] }
                }
              end

              let(:expected_results) { [] }
            end
          end

          shared_examples 'it can sort dependencies' do |sort|
            subject { json_response['dependencies'].pluck('occurrence_id') }

            let(:sort_param) { sort[:by] }
            let(:params) { { sort_by: sort_param, page: 1 } }

            context 'in descending order' do
              let(:params) { super().merge(sort: 'desc') }

              it { is_expected.to eq expected_desc.map(&:id) }
            end

            context 'in ascending order' do
              let(:params) { super().merge(sort: 'asc') }

              it { is_expected.to eq expected_asc.map(&:id) }
            end
          end

          context 'when sorted by packager' do
            it_behaves_like 'it can sort dependencies', by: 'packager' do
              let(:bundler) { occurrences[0] }
              let(:npm) { occurrences[1] }
              let(:yarn) { occurrences[2] }
              let(:nugget) { occurrences[3] }

              let(:expected_asc) { [bundler, npm, nugget, yarn] }
              let(:expected_desc) { [yarn, nugget, npm, bundler] }
            end
          end

          context 'when sorted by severity' do
            it_behaves_like 'it can sort dependencies', by: 'severity' do
              let(:critical) { occurrences[0] }
              let(:high) { occurrences[1] }
              let(:low) { occurrences[2] }
              let(:null) { occurrences[3] }

              let(:expected_asc) { [null, low, high, critical] }
              let(:expected_desc) { [critical, high, low, null] }
            end
          end
        end

        it_behaves_like 'tracks govern usage event', 'dependencies' do
          let(:request) { get project_dependencies_path(project, format: :html) }
        end

        it 'pushes the read_advanced_dependency_management ability to the frontend' do
          expect_next_instance_of(described_class) do |controller|
            expect(controller).to receive(:push_frontend_ability).with(
              ability: :read_advanced_dependency_management,
              resource: project,
              user: user
            )
          end

          show_dependency_list
        end

        it 'tracks show_dependency_list action' do
          expect { show_dependency_list }.to trigger_internal_events('visit_dependency_list').with(
            user: user,
            project: project
          )
        end

        it 'tracks project_dependencies_path visits' do
          expect { get project_dependencies_path(project, format: :json) }
            .to trigger_internal_events('called_dependency_api').with(
              user: user,
              project: project,
              additional_properties: { label: 'json' }
            )
        end
      end

      context 'when licensed feature is unavailable' do
        let(:user) { developer }

        it 'returns 403 for a JSON request' do
          get project_dependencies_path(project, format: :json)

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'returns a 404 for an HTML request' do
          get project_dependencies_path(project, format: :html)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it_behaves_like "doesn't track govern usage event", 'dependencies' do
          let(:request) { get project_dependencies_path(project, format: :html) }
        end

        it 'does not record events or metrics' do
          expect { valid_request }.not_to trigger_internal_events('visit_dependency_list')
        end
      end
    end

    context 'with unauthorized user' do
      let(:user) { guest }

      before do
        stub_licensed_features(dependency_scanning: true)
      end

      it 'returns 403 for a JSON request' do
        get project_dependencies_path(project, format: :json)

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'returns a 404 for an HTML request' do
        get project_dependencies_path(project, format: :html)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like "doesn't track govern usage event", 'dependencies' do
        let(:request) { get project_dependencies_path(project, format: :html) }
      end

      it 'does not record events or metrics' do
        expect { valid_request }.not_to trigger_internal_events('visit_dependency_list')
      end
    end
  end

  describe 'GET #licenses' do
    include_context '"Security and compliance" permissions' do
      let(:user) { developer }
      let(:valid_request) { get licenses_project_dependencies_path(project), as: :json }
    end

    context 'with authorized user' do
      context 'when feature is available' do
        let(:user) { developer }

        before do
          stub_licensed_features(dependency_scanning: true, license_scanning: true, security_dashboard: true)
        end

        it 'returns http status :ok' do
          valid_request

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'returns licenses from Gitlab::SPDX::Catalogue sorted by name' do
          expect(Gitlab::SPDX::Catalogue).to receive(:latest_licenses).and_call_original

          valid_request

          expect(json_response['licenses']).not_to be_empty
          license_names = json_response['licenses'].pluck('name')
          expect(license_names.sort).to eq(license_names)
        end
      end

      context 'when licensed feature is unavailable' do
        let(:user) { developer }

        it 'returns 403 for a JSON request' do
          valid_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'with unauthorized user' do
      let(:user) { guest }

      it 'returns 403 for a JSON request' do
        valid_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
