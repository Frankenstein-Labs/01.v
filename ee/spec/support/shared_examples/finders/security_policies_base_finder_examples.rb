# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'security policies finder' do
  subject { described_class.new(actor, object, params).execute }

  shared_examples 'when user does not have developer role in project/group' do
    it 'returns empty collection' do
      is_expected.to be_empty
    end
  end

  describe '#execute' do
    context 'when feature is not licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
        object.add_developer(actor)
      end

      it 'returns empty collection' do
        is_expected.to be_empty
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when configuration is associated to project' do
        # Project not belonging to group
        let_it_be(:object, freeze: false) { create(:project) }

        it_behaves_like 'when user does not have developer role in project/group'

        context 'when user has developer role in the project' do
          before do
            object.add_developer(actor) # rubocop:disable RSpec/BeforeAllRoleAssignment -- let(:actor) is used here
          end

          it 'returns policies with project' do
            is_expected.to match_array([policy.merge(
              {
                config: policy_configuration,
                project: object,
                namespace: nil,
                inherited: false,
                csp: false,
                **expected_extra_attrs
              })])
          end

          context 'when relationship argument is provided as DESCENDANT' do
            let(:relationship) { :descendant }

            it 'returns policies with project only' do
              is_expected.to match_array([policy.merge(
                {
                  config: policy_configuration,
                  project: object,
                  namespace: nil,
                  inherited: false,
                  csp: false,
                  **expected_extra_attrs
                })])
            end
          end

          context 'when include_unscoped is false' do
            let(:include_unscoped) { false }

            context 'when project is not included in the scope' do
              let(:policy_scope) do
                {
                  compliance_frameworks: [],
                  projects: {
                    including: [],
                    excluding: [{
                      id: object.id
                    }]
                  }
                }
              end

              it 'returns empty collection' do
                is_expected.to be_empty
              end
            end

            context 'when project is included in the scope' do
              let(:policy_scope) do
                {
                  compliance_frameworks: [],
                  projects: {
                    including: [{
                      id: object.id
                    }],
                    excluding: []
                  }
                }
              end

              it 'returns policies with project' do
                is_expected.to match_array([policy.merge(
                  {
                    config: policy_configuration,
                    project: object,
                    namespace: nil,
                    inherited: false,
                    csp: false,
                    **expected_extra_attrs
                  })])
              end
            end
          end
        end
      end

      context 'when configuration is associated to namespace' do
        # Project belonging to group
        let_it_be(:object, freeze: false) { create(:project, group: group) }
        let!(:policy_configuration) { nil }

        let!(:group_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            :namespace,
            security_policy_management_project: policy_management_project,
            namespace: group
          )
        end

        it_behaves_like 'when user does not have developer role in project/group'

        context 'when user has developer role in the group' do
          before do
            object.add_developer(actor) # rubocop:disable RSpec/BeforeAllRoleAssignment -- let(:actor) is used here
          end

          context 'when relationship argument is not provided' do
            it 'returns no policies' do
              is_expected.to be_empty
            end
          end

          context 'when relationship argument is provided as INHERITED' do
            let(:relationship) { :inherited }

            it 'returns scan policies for groups only' do
              is_expected.to match_array([policy.merge(
                {
                  config: group_policy_configuration,
                  project: nil,
                  namespace: group,
                  inherited: true,
                  csp: false,
                  **expected_extra_attrs
                })])
            end

            context 'when group is designated as CSP' do
              include Security::PolicyCspHelpers

              before do
                stub_csp_group(group)
              end

              it 'returns scan policies for groups only' do
                is_expected.to match_array([policy.merge(
                  {
                    config: group_policy_configuration,
                    project: nil,
                    namespace: group,
                    inherited: true,
                    csp: true,
                    **expected_extra_attrs
                  })])
              end
            end
          end

          context 'when relationship argument is provided as DESCENDANT' do
            let(:relationship) { :descendant }

            let!(:sub_group) { create(:group, parent: group) }
            let!(:sub_group_policy_configuration) do
              create(
                :security_orchestration_policy_configuration,
                :namespace,
                security_policy_management_project: policy_management_project,
                namespace: sub_group
              )
            end

            let(:object) { group }

            it 'returns scan policies for descendant groups' do
              is_expected.to match_array(
                [
                  policy.merge(
                    {
                      config: group_policy_configuration,
                      project: nil,
                      namespace: object,
                      inherited: false,
                      csp: false,
                      **expected_extra_attrs
                    }),
                  policy.merge(
                    {
                      config: sub_group_policy_configuration,
                      project: nil,
                      namespace: sub_group,
                      inherited: true,
                      csp: false,
                      **expected_extra_attrs
                    })
                ])
            end

            context 'when there are more than the limit of descendant configurations' do
              it 'returns only up to the limit of configurations' do
                stub_const('Security::SecurityPolicyBaseFinder::DESCENDANT_POLICY_CONFIGURATIONS_LIMIT', 2)

                result = described_class.new(actor, object, { relationship: :descendant }).execute
                expect(result.count).to eq(2)
              end

              it 'limits results when there are more configurations than the stubbed limit' do
                3.times do
                  additional_group = create(:group, parent: group)
                  create(
                    :security_orchestration_policy_configuration,
                    :namespace,
                    security_policy_management_project: policy_management_project,
                    namespace: additional_group
                  )

                  allow_next_instance_of(Repository) do |repository|
                    allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
                  end
                end

                stub_const('Security::SecurityPolicyBaseFinder::DESCENDANT_POLICY_CONFIGURATIONS_LIMIT', 2)

                result = described_class.new(actor, object, { relationship: :descendant }).execute
                expect(result.count).to eq(2)
                expect(result.pluck(:name)).to all(eq(policy[:name]))
              end
            end
          end
        end
      end

      context 'when configuration is associated to project and namespace' do
        let!(:group_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            :namespace,
            security_policy_management_project: policy_management_project,
            namespace: group
          )
        end

        it_behaves_like 'when user does not have developer role in project/group'

        context 'when user has developer role in the group' do
          before do
            object.add_developer(actor)
          end

          context 'when relationship argument is not provided' do
            it 'returns scan policies for project only' do
              is_expected.to match_array([policy.merge(
                {
                  config: policy_configuration,
                  project: object,
                  namespace: nil,
                  inherited: false,
                  csp: false,
                  **expected_extra_attrs
                })])
            end
          end

          context 'when relationship argument is provided as INHERITED' do
            let(:relationship) { :inherited }

            it 'returns policies defined for both project and namespace' do
              is_expected.to match_array(
                [
                  policy.merge(
                    {
                      config: policy_configuration,
                      project: object,
                      namespace: nil,
                      inherited: false,
                      csp: false,
                      **expected_extra_attrs
                    }),
                  policy.merge(
                    {
                      config: group_policy_configuration,
                      project: nil,
                      namespace: group,
                      inherited: true,
                      csp: false,
                      **expected_extra_attrs
                    })
                ])
            end
          end

          context 'when relationship argument is provided as INHERITED_ONLY' do
            let(:relationship) { :inherited_only }

            it 'returns policies defined for namespace only' do
              is_expected.to match_array([policy.merge(
                {
                  config: group_policy_configuration,
                  project: nil,
                  namespace: group,
                  inherited: true,
                  csp: false,
                  **expected_extra_attrs
                })])
            end
          end

          context 'when relationship argument is provided as DESCENDANT' do
            let(:relationship) { :descendant }

            it 'returns scan policies for descendants only' do
              is_expected.to match_array(
                [
                  policy.merge(
                    {
                      config: policy_configuration,
                      project: object,
                      namespace: nil,
                      inherited: false,
                      csp: false,
                      **expected_extra_attrs
                    })
                ])
            end
          end
        end
      end

      context 'for policy deduplication' do
        let_it_be(:dedup_management_project, freeze: false) { create(:project) }
        let_it_be(:dedup_group, freeze: false) { create(:group) }
        let_it_be(:dedup_project_1, freeze: false) { create(:project, group: dedup_group) }
        let_it_be(:dedup_project_2, freeze: false) { create(:project, group: dedup_group) }
        let_it_be(:dedup_actor, freeze: false) { create(:user) }

        let!(:dedup_config_1) do
          create(
            :security_orchestration_policy_configuration,
            security_policy_management_project: dedup_management_project,
            project: dedup_project_1
          )
        end

        let!(:dedup_config_2) do
          create(
            :security_orchestration_policy_configuration,
            security_policy_management_project: dedup_management_project,
            project: dedup_project_2
          )
        end

        before_all do
          dedup_group.add_developer(dedup_actor)
          dedup_project_1.add_developer(dedup_actor)
          dedup_project_2.add_developer(dedup_actor)
        end

        before do
          stub_licensed_features(security_orchestration_policies: true)

          allow_next_instances_of(Repository, 2) do |repository|
            allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
          end
        end

        context 'when deduplicate_policies is true' do
          it 'deduplicates policies with same security_policy_management_project_id' do
            result = described_class.new(
              dedup_actor,
              dedup_group,
              { relationship: :descendant, deduplicate_policies: true }
            ).execute

            expect(result.count).to eq(1)
            expect(result.first[:name]).to eq(policy[:name])
          end
        end

        context 'when deduplicate_policies is false' do
          it 'returns all policies without deduplication' do
            result = described_class.new(
              dedup_actor,
              dedup_group,
              { relationship: :descendant, deduplicate_policies: false }
            ).execute

            expect(result.count).to eq(2)
            expect(result.pluck(:name)).to all(eq(policy[:name]))

            config_ids = result.map { |policy| policy[:config].id }
            expect(config_ids).to contain_exactly(dedup_config_1.id, dedup_config_2.id)
          end
        end

        context 'when deduplicate_policies is not provided' do
          it 'defaults to no deduplication' do
            result = described_class.new(dedup_actor, dedup_group, { relationship: :descendant }).execute

            expect(result.count).to eq(2)
          end
        end
      end
    end
  end
end
