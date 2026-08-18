# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ci::Catalog::Resources::ProjectComponentUsagesResolver, feature_category: :pipeline_composition do
  include GraphqlHelpers

  let_it_be(:current_user, freeze: false) { create(:user) }
  let_it_be(:catalog_resource_project, freeze: false) { create(:project) }
  let_it_be(:catalog_resource, freeze: false) { create(:ci_catalog_resource, project: catalog_resource_project) }
  let_it_be(:version, freeze: false) { create(:ci_catalog_resource_version, catalog_resource: catalog_resource) }
  let_it_be(:component, freeze: false) do
    create(:ci_catalog_resource_component, catalog_resource: catalog_resource, version: version)
  end

  let_it_be(:using_project_1, freeze: false) { create(:project, :public) }
  let_it_be(:using_project_2, freeze: false) { create(:project, :public) }
  let_it_be(:private_project, freeze: false) { create(:project, :private) }

  let_it_be(:usage_1, freeze: false) do
    create(:catalog_resource_component_last_usage,
      component: component,
      catalog_resource: catalog_resource,
      used_by_project_id: using_project_1.id
    )
  end

  let_it_be(:usage_2, freeze: false) do
    create(:catalog_resource_component_last_usage,
      component: component,
      catalog_resource: catalog_resource,
      used_by_project_id: using_project_2.id
    )
  end

  let_it_be(:private_usage, freeze: false) do
    create(:catalog_resource_component_last_usage,
      component: component,
      catalog_resource: catalog_resource,
      used_by_project_id: private_project.id
    )
  end

  describe '#resolve' do
    let(:resolve_component_usages) do
      resolve(described_class, obj: catalog_resource, ctx: { current_user: current_user })
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(ci_component_analytics: false)
      end

      context 'when user is a maintainer' do
        before_all do
          catalog_resource_project.add_maintainer(current_user)
        end

        it 'raises a resource not available error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
            resolve_component_usages
          end
        end
      end
    end

    context 'when feature flag is enabled' do
      context 'when licensed' do
        before do
          stub_licensed_features(ci_component_usages_in_projects: true)
        end

        context 'when on SaaS' do
          before do
            stub_saas_features(ci_component_usages_in_projects: true)
          end

          context 'when user is a maintainer of the catalog resource project' do
            before_all do
              catalog_resource_project.add_maintainer(current_user)
            end

            context 'when there are no usages' do
              let_it_be(:empty_resource, freeze: false) { create(:ci_catalog_resource, project: create(:project)) }

              before_all do
                empty_resource.project.add_maintainer(current_user)
              end

              it 'returns empty array' do
                result = resolve(described_class, obj: empty_resource, ctx: { current_user: current_user })

                expect(result).to eq([])
              end
            end

            context 'when all using projects are private and not visible to the user' do
              let_it_be(:private_only_resource, freeze: false) do
                create(:ci_catalog_resource, project: create(:project))
              end

              let_it_be(:private_only_version, freeze: false) do
                create(:ci_catalog_resource_version, catalog_resource: private_only_resource)
              end

              let_it_be(:private_only_component, freeze: false) do
                create(:ci_catalog_resource_component,
                  catalog_resource: private_only_resource, version: private_only_version)
              end

              let_it_be(:private_only_usage, freeze: false) do
                create(:catalog_resource_component_last_usage,
                  component: private_only_component,
                  catalog_resource: private_only_resource,
                  used_by_project_id: create(:project, :private).id
                )
              end

              before_all do
                private_only_resource.project.add_maintainer(current_user)
              end

              it 'returns empty array' do
                result = resolve(described_class, obj: private_only_resource, ctx: { current_user: current_user })

                expect(result).to eq([])
              end
            end

            it 'returns usages for visible projects only' do
              result = resolve_component_usages

              expect(result.size).to eq(2)
              project_ids = result.map { |r| r[:project].id }
              expect(project_ids).to contain_exactly(using_project_1.id, using_project_2.id)
            end

            context 'when user also has access to private project' do
              before_all do
                private_project.add_developer(current_user)
              end

              it 'includes the private project usage' do
                result = resolve_component_usages

                expect(result.size).to eq(3)
                project_ids = result.map { |r| r[:project].id }
                expect(project_ids).to contain_exactly(using_project_1.id, using_project_2.id, private_project.id)
              end
            end

            context 'with filtering' do
              let_it_be(:other_version) do
                create(:ci_catalog_resource_version, catalog_resource: catalog_resource)
              end

              let_it_be(:other_component) do
                create(:ci_catalog_resource_component,
                  catalog_resource: catalog_resource, version: other_version, name: 'other-component')
              end

              let_it_be(:other_using_project) { create(:project, :public) }

              let_it_be(:other_usage) do
                create(:catalog_resource_component_last_usage,
                  component: other_component,
                  catalog_resource: catalog_resource,
                  used_by_project_id: other_using_project.id)
              end

              def resolve_with(args)
                resolve(described_class, obj: catalog_resource, args: args, ctx: { current_user: current_user })
              end

              context 'when filtering by version_ids' do
                it 'returns only projects using the given single version' do
                  result = resolve_with(version_ids: [other_version.to_global_id])

                  project_ids = result.map { |r| r[:project].id }
                  expect(project_ids).to contain_exactly(other_using_project.id)
                end

                it 'returns projects using any of multiple given versions' do
                  result = resolve_with(version_ids: [version.to_global_id, other_version.to_global_id])

                  project_ids = result.map { |r| r[:project].id }
                  expect(project_ids).to contain_exactly(
                    using_project_1.id,
                    using_project_2.id,
                    other_using_project.id
                  )
                end

                it 'returns empty when none of the versions have usages' do
                  empty_version = create(:ci_catalog_resource_version, catalog_resource: catalog_resource)

                  result = resolve_with(version_ids: [empty_version.to_global_id])

                  expect(result).to eq([])
                end
              end

              context 'when filtering by component_name' do
                it 'returns only projects using the named component' do
                  result = resolve_with(component_name: 'other-component')

                  project_ids = result.map { |r| r[:project].id }
                  expect(project_ids).to contain_exactly(other_using_project.id)
                end

                it 'returns empty when the component name does not exist' do
                  result = resolve_with(component_name: 'does-not-exist')

                  expect(result).to eq([])
                end
              end

              context 'when filtering by both version_ids and component_name' do
                it 'applies both filters with AND semantics' do
                  result = resolve_with(
                    version_ids: [other_version.to_global_id],
                    component_name: 'other-component'
                  )

                  project_ids = result.map { |r| r[:project].id }
                  expect(project_ids).to contain_exactly(other_using_project.id)
                end

                it 'returns empty when filters do not intersect' do
                  result = resolve_with(
                    version_ids: [version.to_global_id],
                    component_name: 'other-component'
                  )

                  expect(result).to eq([])
                end
              end
            end

            context 'with sorting' do
              # Dedicated catalog resource so the outer fixtures don't leak into sort assertions.
              let_it_be(:sort_resource, freeze: false) { create(:ci_catalog_resource, project: create(:project)) }
              let_it_be(:v1, freeze: false) do
                create(:ci_catalog_resource_version, catalog_resource: sort_resource, semver: '1.0.0')
              end

              let_it_be(:v2, freeze: false) do
                create(:ci_catalog_resource_version, catalog_resource: sort_resource, semver: '2.0.0')
              end

              let_it_be(:v3, freeze: false) do
                create(:ci_catalog_resource_version, catalog_resource: sort_resource, semver: '3.0.0')
              end

              let_it_be(:project_alpha, freeze: false) { create(:project, :public, name: 'alpha') }
              let_it_be(:project_bravo, freeze: false) { create(:project, :public, name: 'bravo') }
              let_it_be(:project_charlie, freeze: false) { create(:project, :public, name: 'charlie') }

              # alpha   uses v1 only        last_used 5 days ago
              # bravo   uses v1 and v2      last_used 10 days ago (most recent of its rows)
              # charlie uses v3 only        last_used 1 day ago
              let_it_be(:sort_usages, freeze: false) do
                comp_v1 = create(:ci_catalog_resource_component, catalog_resource: sort_resource, version: v1)
                comp_v2 = create(:ci_catalog_resource_component, catalog_resource: sort_resource, version: v2)
                comp_v3 = create(:ci_catalog_resource_component, catalog_resource: sort_resource, version: v3)

                [
                  create(:catalog_resource_component_last_usage, component: comp_v1, catalog_resource: sort_resource,
                    used_by_project_id: project_alpha.id, last_used_date: 5.days.ago.to_date),
                  create(:catalog_resource_component_last_usage, component: comp_v1, catalog_resource: sort_resource,
                    used_by_project_id: project_bravo.id, last_used_date: 15.days.ago.to_date),
                  create(:catalog_resource_component_last_usage, component: comp_v2, catalog_resource: sort_resource,
                    used_by_project_id: project_bravo.id, last_used_date: 10.days.ago.to_date),
                  create(:catalog_resource_component_last_usage, component: comp_v3, catalog_resource: sort_resource,
                    used_by_project_id: project_charlie.id, last_used_date: 1.day.ago.to_date)
                ]
              end

              before_all do
                sort_resource.project.add_maintainer(current_user)
              end

              def resolve_with(args)
                resolve(described_class, obj: sort_resource, args: args, ctx: { current_user: current_user },
                  arg_style: :internal)
              end

              def project_names(result)
                result.map { |r| r[:project].name }
              end

              # min versions: alpha=1, bravo=1, charlie=3
              # max versions: alpha=1, bravo=2, charlie=3
              # most-recent dates: alpha=5d, bravo=10d, charlie=1d

              context 'when sort is not provided' do
                it 'defaults to OLDEST_VERSION_ASC' do
                  default = resolve_with({})
                  explicit = resolve_with(sort: :oldest_version_asc)

                  expect(project_names(default)).to eq(project_names(explicit))
                end
              end

              it 'sorts by oldest version ascending (alpha and bravo at top, charlie last)' do
                result = resolve_with(sort: :oldest_version_asc)
                # alpha and bravo both have oldest=v1; charlie has oldest=v3
                expect(project_names(result).last).to eq('charlie')
                expect(project_names(result).take(2)).to contain_exactly('alpha', 'bravo')
              end

              it 'sorts by oldest version descending (charlie first)' do
                result = resolve_with(sort: :oldest_version_desc)
                expect(project_names(result).first).to eq('charlie')
              end

              it 'sorts by newest version ascending (alpha first, charlie last)' do
                result = resolve_with(sort: :version_asc)
                # max versions: alpha=v1, bravo=v2, charlie=v3
                expect(project_names(result)).to include('alpha', 'bravo', 'charlie')
                expect(project_names(result).first).to eq('alpha')
                expect(project_names(result).last).to eq('charlie')
              end

              it 'sorts by newest version descending (charlie first)' do
                result = resolve_with(sort: :version_desc)
                expect(project_names(result).first).to eq('charlie')
                expect(project_names(result).last).to eq('alpha')
              end

              it 'sorts by last used ascending (most stale first)' do
                result = resolve_with(sort: :last_used_asc)
                # most-recent per project: alpha=5d, bravo=10d, charlie=1d
                expect(project_names(result)).to eq(%w[bravo alpha charlie])
              end

              it 'sorts by last used descending (most recent first)' do
                result = resolve_with(sort: :last_used_desc)
                expect(project_names(result)).to eq(%w[charlie alpha bravo])
              end

              it 'sorts by project name ascending' do
                result = resolve_with(sort: :project_name_asc)
                expect(project_names(result)).to eq(%w[alpha bravo charlie])
              end

              it 'sorts by project name descending' do
                result = resolve_with(sort: :project_name_desc)
                expect(project_names(result)).to eq(%w[charlie bravo alpha])
              end

              context 'when combined with filtering' do
                it 'applies sort after filter' do
                  result = resolve_with(version_ids: [v1.to_global_id], sort: :project_name_asc)

                  expect(project_names(result)).to eq(%w[alpha bravo])
                end
              end
            end
          end

          context 'when user is not a maintainer of the catalog resource project' do
            let_it_be(:non_maintainer) { create(:user) }

            let(:resolve_component_usages) do
              resolve(described_class, obj: catalog_resource, ctx: { current_user: non_maintainer })
            end

            it 'returns nil' do
              expect(resolve_component_usages).to be_nil
            end

            context 'when user is a developer' do
              before_all do
                catalog_resource_project.add_developer(non_maintainer)
              end

              it 'returns nil' do
                expect(resolve_component_usages).to be_nil
              end
            end
          end

          context 'when there is no current user' do
            let(:resolve_component_usages) do
              resolve(described_class, obj: catalog_resource, ctx: { current_user: nil })
            end

            it 'returns nil' do
              expect(resolve_component_usages).to be_nil
            end
          end
        end

        context 'when user is an admin', :enable_admin_mode do
          let_it_be(:current_user) { create(:admin) }

          it 'returns usages for all visible projects' do
            result = resolve_component_usages

            expect(result.size).to eq(3)
            project_ids = result.map { |r| r[:project].id }
            expect(project_ids).to contain_exactly(using_project_1.id, using_project_2.id, private_project.id)
          end
        end
      end

      context 'when not licensed' do
        before do
          stub_licensed_features(ci_component_usages_in_projects: false)
          stub_saas_features(ci_component_usages_in_projects: false)
        end

        context 'when user is a maintainer' do
          before_all do
            catalog_resource_project.add_maintainer(current_user)
          end

          it 'raises a resource not available error' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
              resolve_component_usages
            end
          end
        end
      end
    end
  end
end
