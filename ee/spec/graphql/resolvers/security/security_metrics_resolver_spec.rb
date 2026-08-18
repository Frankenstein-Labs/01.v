# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::SecurityMetricsResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:project2) { create(:project, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  let(:ctx) { { current_user: current_user } }

  subject(:resolved_metrics) do
    resolve(described_class, obj: operate_on, args: args, ctx: ctx)
  end

  describe '#resolve' do
    let(:args) { {} }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    specify do
      expect(described_class).to have_nullable_graphql_type(Types::Security::SecurityMetricsType)
    end

    shared_examples 'returns the object when authorized' do
      it 'returns the object' do
        expect(resolved_metrics).to eq(operate_on)
      end

      context 'with filter arguments' do
        let(:args) { filter_args }

        it 'returns the object with filters applied' do
          expect(resolved_metrics).to eq(operate_on)
        end
      end

      context 'with invalid arguments' do
        let(:args) { { project_id: ['invalid-gid'] } }

        it 'handles invalid arguments gracefully' do
          expect(resolved_metrics).to eq(operate_on)
        end
      end
    end

    shared_examples 'returns nil when unauthorized' do
      it 'returns nil' do
        expect(resolved_metrics).to be_nil
      end
    end

    context 'when operated on a group' do
      let(:operate_on) { group }
      let(:filter_args) do
        {
          project_id: [project.to_global_id.to_s]
        }
      end

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        it_behaves_like 'returns the object when authorized'

        context 'with tracked_ref_ids' do
          let(:args) { { tracked_ref_ids: [GlobalID.new('gid://gitlab/Security::ProjectTrackedContext/1')] } }

          it 'does not set tracked_ref_ids in context' do
            resolved_metrics

            expect(ctx[:tracked_ref_ids]).to be_nil
          end
        end

        context 'with security_attributes_filters' do
          let_it_be(:category) { create(:security_category, namespace: group, name: 'Environment') }
          let_it_be(:attr_production) do
            create(:security_attribute, security_category: category, namespace: group, name: 'Production')
          end

          let_it_be(:attr_critical) do
            create(:security_attribute, security_category: category, namespace: group, name: 'Critical')
          end

          let_it_be(:project1_production) do
            create(:project_to_security_attribute, project: project, security_attribute: attr_production,
              traversal_ids: project.namespace.traversal_ids)
          end

          let_it_be(:project2_critical) do
            create(:project_to_security_attribute, project: project2, security_attribute: attr_critical,
              traversal_ids: project2.namespace.traversal_ids)
          end

          let(:service_instance) { instance_double(::Security::Dashboard::SecurityAttributesProjectFilterService) }

          context 'when security_attributes_filters is provided' do
            let(:args) do
              {
                security_attributes_filters: [
                  { operator: 'IS_ONE_OF', attributes: [attr_production.to_global_id.to_s] }
                ]
              }
            end

            it 'calls SecurityAttributesProjectFilterService' do
              expect(::Security::Dashboard::SecurityAttributesProjectFilterService)
                .to receive(:new)
                .with(namespace: group, attribute_filters: anything)
                .and_return(service_instance)
              expect(service_instance).to receive(:execute)
                .and_return({ status: :success, project_ids: [project.id] })

              expect(resolved_metrics).to eq(group)
            end
          end

          context 'when both project_id and security_attributes_filters are provided' do
            let(:args) do
              {
                project_id: [project.to_global_id.to_s, project2.to_global_id.to_s],
                security_attributes_filters: [
                  { operator: 'IS_ONE_OF', attributes: [attr_production.to_global_id.to_s] }
                ]
              }
            end

            it 'calls SecurityAttributesProjectFilterService for intersection' do
              expect(::Security::Dashboard::SecurityAttributesProjectFilterService)
                .to receive(:new)
                .with(namespace: group, attribute_filters: anything)
                .and_return(service_instance)
              expect(service_instance).to receive(:execute)
                .and_return({ status: :success, project_ids: [project.id] })

              expect(resolved_metrics).to eq(group)
            end
          end

          context 'when only project_id is provided without security_attributes_filters' do
            let(:args) do
              {
                project_id: [project.to_global_id.to_s]
              }
            end

            it 'does not call SecurityAttributesProjectFilterService' do
              expect(::Security::Dashboard::SecurityAttributesProjectFilterService).not_to receive(:new)

              expect(resolved_metrics).to eq(group)
            end
          end

          context 'when project_id is a raw numeric string instead of a GID' do
            let(:args) do
              {
                project_id: [project.id.to_s]
              }
            end

            it 'falls back to parsing the numeric ID' do
              resolved_metrics

              expect(ctx[:project_id]).to eq([project.id])
            end
          end

          context 'when the service returns empty project_ids' do
            let(:attribute_filters) do
              [{ operator: 'IS_ONE_OF', attributes: [attr_production.to_global_id.to_s] }]
            end

            before do
              allow(::Security::Dashboard::SecurityAttributesProjectFilterService)
                .to receive(:new).and_return(service_instance)
              allow(service_instance).to receive(:execute)
                .and_return({ status: :success, project_ids: returned_project_ids })
            end

            context 'with only attribute filters' do
              let(:args) { { security_attributes_filters: attribute_filters } }
              let(:returned_project_ids) { [] }

              it 'sets context[:project_id] to sentinel value so downstream queries return no results' do
                resolved_metrics

                expect(ctx[:project_id]).to eq(described_class::EMPTY_PROJECT_IDS_SENTINEL)
              end
            end

            context 'with attribute filters and explicit project_ids' do
              let(:args) { { project_id: [project.to_global_id.to_s], security_attributes_filters: attribute_filters } }
              let(:returned_project_ids) { [project2.id] }

              it 'sets context[:project_id] to sentinel value when intersection is empty' do
                resolved_metrics

                expect(ctx[:project_id]).to eq(described_class::EMPTY_PROJECT_IDS_SENTINEL)
              end
            end
          end
        end
      end

      context 'when the current user does not have access' do
        it_behaves_like 'returns nil when unauthorized'
      end
    end

    context 'when operated on a project' do
      let(:operate_on) { project }
      let(:filter_args) do
        {
          severity: ['critical'],
          scanner: ['sast']
        }
      end

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        it_behaves_like 'returns the object when authorized'

        context 'with tracked_ref_ids' do
          let(:args) { { tracked_ref_ids: [GlobalID.new('gid://gitlab/Security::ProjectTrackedContext/1')] } }

          it 'sets tracked_ref_ids in context' do
            resolved_metrics

            expect(ctx[:tracked_ref_ids]).to eq(['1'])
          end

          context 'when vulnerabilities_across_contexts feature flag is disabled' do
            before do
              stub_feature_flags(vulnerabilities_across_contexts: false)
            end

            it 'does not set tracked_ref_ids in context' do
              resolved_metrics

              expect(ctx[:tracked_ref_ids]).to be_nil
            end
          end
        end

        context 'without tracked_ref_ids' do
          let(:args) { {} }

          it 'does not set tracked_ref_ids in context' do
            resolved_metrics

            expect(ctx[:tracked_ref_ids]).to be_nil
          end
        end

        context 'with security_attributes_filters' do
          let(:args) do
            {
              security_attributes_filters: [
                { operator: 'is_one_of', attributes: [1] }
              ]
            }
          end

          it 'does not call SecurityAttributesProjectFilterService' do
            expect(::Security::Dashboard::SecurityAttributesProjectFilterService).not_to receive(:new)

            resolve(described_class, obj: operate_on, args: args, ctx: ctx, arg_style: :internal)
          end
        end
      end

      context 'when the current user does not have access' do
        it_behaves_like 'returns nil when unauthorized'
      end
    end

    context 'when operated on an organization' do
      let_it_be(:organization) { create(:organization) }

      let(:operate_on) { organization }
      let(:filter_args) { {} }

      context 'when the current user is an organization owner' do
        before_all do
          create(:organization_user, :owner, organization: organization, user: current_user)
        end

        it_behaves_like 'returns the object when authorized'

        context 'when the organization_security_dashboard feature flag is disabled' do
          before do
            stub_feature_flags(organization_security_dashboard: false)
          end

          it_behaves_like 'returns nil when unauthorized'
        end

        context 'when project_id filter is provided' do
          let(:args) { { project_id: ['gid://gitlab/Project/1'] } }

          it 'applies the project_id filter' do
            resolved_metrics

            expect(ctx[:project_id]).to eq([1])
          end
        end

        context 'when security_attributes_filters are provided' do
          let(:args) do
            {
              security_attributes_filters: [{ operator: 'is_one_of', attributes: %w[1 2] }]
            }
          end

          it 'ignores them without raising' do
            expect { resolved_metrics }.not_to raise_error

            expect(ctx[:project_id]).to be_nil
          end
        end
      end

      context 'when the current user does not have access' do
        # Use a fresh non-member here: User#owns_organization? memoizes its result, and the shared
        # let_it_be(:current_user) is turned into an owner by the sibling context above.
        let(:current_user) { create(:user) }

        it_behaves_like 'returns nil when unauthorized'
      end
    end

    context 'when operated on an object other than group or project' do
      let_it_be(:operate_on) { InstanceSecurityDashboard.new(current_user, project_ids: [project.id]) }

      let(:filter_args) do
        {
          project_id: [project.to_global_id.to_s]
        }
      end

      context 'when the current user has access' do
        before_all do
          project.add_developer(current_user)
        end

        it 'returns nil' do
          expect(resolved_metrics).to be_nil
        end
      end
    end

    context 'when security_dashboard feature flag is disabled' do
      let(:operate_on) { group }

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'returns nil when unauthorized'
    end
  end
end
