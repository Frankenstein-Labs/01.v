# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyScopeChecker, feature_category: :security_policy_management do
  let_it_be_with_refind(:root_group) { create(:group) }
  let_it_be_with_refind(:group) { create(:group, parent: root_group) }
  let_it_be_with_refind(:other_group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:compliance_framework) { create(:compliance_framework, namespace: root_group) }

  let(:service) { described_class.new(project: project) }

  # It is expected that the caller defines `base_policy_scope`
  shared_examples 'match_mode expectations' do |nil_result:, all_result:, any_result:|
    where(:match_mode, :expected_result) do
      [
        [nil,   nil_result],
        ['all', all_result],
        ['any', any_result]
      ]
    end

    with_them do
      let(:policy_scope) { match_mode ? base_policy_scope.merge(match_mode: match_mode) : base_policy_scope }

      it { is_expected.to eq expected_result }
    end
  end

  shared_examples 'scoped security attribute checker' do |scope_key:, template_type:, category_name:, attribute_1_name:,
    attribute_2_name:|

    let_it_be(:category) do
      create(:security_category, namespace: root_group, template_type: template_type, name: category_name)
    end

    let_it_be(:attribute_1) do
      create(:security_attribute, namespace: root_group, security_category: category, name: attribute_1_name)
    end

    let_it_be(:attribute_2) do
      create(:security_attribute, namespace: root_group, security_category: category, name: attribute_2_name)
    end

    let_it_be(:_project_attribute_1) do
      create(:project_to_security_attribute, project: project, security_attribute: attribute_1,
        traversal_ids: project.namespace.traversal_ids)
    end

    context 'with including scope' do
      context 'when project has the included attribute' do
        let(:policy_scope) { { scope_key => { including: [{ id: attribute_1.id }] } } }

        it { is_expected.to be true }

        it 'triggers an internal event' do
          expect { policy_applicable }.to trigger_internal_events('check_policy_scope_for_security_policy').with(
            project: project,
            additional_properties: { label: scope_key.to_s }
          )
        end
      end

      context 'when project does not have the included attribute' do
        let(:policy_scope) { { scope_key => { including: [{ id: attribute_2.id }] } } }

        it { is_expected.to be false }
      end
    end

    context 'with excluding scope' do
      context 'when project has the excluded attribute' do
        let(:policy_scope) { { scope_key => { excluding: [{ id: attribute_1.id }] } } }

        it { is_expected.to be false }
      end

      context 'when project does not have the excluded attribute' do
        let(:policy_scope) { { scope_key => { excluding: [{ id: attribute_2.id }] } } }

        it { is_expected.to be true }
      end
    end

    context 'when scope is combined with project scope' do
      let(:base_policy_scope) do
        {
          projects: { including: [{ id: project.id }] },
          scope_key => { including: [{ id: attribute_1.id }] }
        }
      end

      it_behaves_like 'match_mode expectations', nil_result: true, all_result: true, any_result: true
    end

    context 'when project scope matches but attribute scope does not' do
      let(:base_policy_scope) do
        {
          projects: { including: [{ id: project.id }] },
          scope_key => { including: [{ id: attribute_2.id }] }
        }
      end

      it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
    end

    context 'when scope has an empty object' do
      let(:policy_scope) { { scope_key => {} } }

      it 'treats empty scope as no scope restriction and returns true' do
        is_expected.to be true
      end
    end

    context 'when security_attributes_policy_scope feature flag is disabled' do
      before do
        stub_feature_flags(security_attributes_policy_scope: false)
      end

      let(:policy_scope) { { scope_key => { including: [{ id: attribute_1.id }] } } }

      it 'ignores the scope and returns true' do
        is_expected.to be true
      end
    end
  end

  shared_examples 'policy scope checker' do
    # When no scope restrictions are defined, policy should ALWAYS apply regardless of match_mode.
    # This ensures backward compatibility and intuitive behavior: missing scope = apply to all.
    context 'when no scope restrictions are defined (policy applies to all projects)' do
      context 'when policy_scope is empty hash' do
        let(:policy_scope) { {} }

        it { is_expected.to be true }
      end

      context 'when policy scope has empty projects and groups objects' do
        where(:match_mode) do
          [nil, 'all', 'any']
        end

        with_them do
          let(:policy_scope) { { match_mode: match_mode, projects: {}, groups: {} }.compact }

          it 'returns true regardless of match_mode' do
            is_expected.to be true
          end
        end
      end

      context 'when only match_mode is set' do
        where(:match_mode) do
          %w[all any]
        end

        with_them do
          let(:policy_scope) { { match_mode: match_mode } }

          it 'returns true because no scope restrictions are defined' do
            is_expected.to be true
          end
        end
      end
    end

    context 'when policy scope has empty including and excluding arrays' do
      where(:match_mode) do
        [nil, 'all', 'any']
      end

      with_them do
        let(:policy_scope) do
          {
            match_mode: match_mode,
            compliance_frameworks: [],
            projects: { including: [], excluding: [] },
            groups: { including: [], excluding: [] }
          }.compact
        end

        it 'returns true regardless of match_mode' do
          is_expected.to be true
        end
      end
    end

    context 'when one scope matches and another does not' do
      context 'when project matches, group does not' do
        let(:base_policy_scope) do
          {
            projects: { including: [{ id: project.id }] },
            groups: { including: [{ id: other_group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
      end

      context 'when project excluded, group matches' do
        let(:base_policy_scope) do
          {
            projects: { excluding: [{ id: project.id }] },
            groups: { including: [{ id: group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
      end

      context 'when group matches, project does not' do
        let(:base_policy_scope) do
          {
            projects: { including: [{ id: -1 }] },
            groups: { including: [{ id: group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
      end
    end

    context 'when policy is scoped for compliance framework' do
      let(:policy_scope) do
        {
          compliance_frameworks: [{ id: compliance_framework.id }]
        }
      end

      it "triggers an internal event" do
        expect { policy_applicable }.to trigger_internal_events('check_policy_scope_for_security_policy').with(
          project: project,
          additional_properties: { label: 'compliance_framework' }
        )
      end

      context 'when project does not have compliance framework set' do
        it { is_expected.to be false }
      end

      context 'when project have compliance framework set' do
        let_it_be(:compliance_framework_project_setting) do
          create(:compliance_framework_project_setting,
            project: project,
            compliance_management_framework: compliance_framework)
        end

        it { is_expected.to be true }

        context 'when project has multiple compliance frameworks set' do
          let_it_be(:compliance_framework_2) { create(:compliance_framework, :sox, namespace: root_group) }
          let_it_be(:compliance_framework_project_setting) do
            create(:compliance_framework_project_setting,
              project: project,
              compliance_management_framework: compliance_framework_2)
          end

          let(:policy_scope) do
            {
              compliance_frameworks: [{ id: compliance_framework_2.id }]
            }
          end

          it { is_expected.to be true }
        end

        context 'when policy additionally excludes the project from policy' do
          let(:policy_scope) do
            {
              compliance_frameworks: [{ id: compliance_framework.id }],
              projects: {
                excluding: [{ id: project.id }]
              }
            }
          end

          it { is_expected.to be false }

          context 'with different match_mode values' do
            where(:match_mode, :expected_result) do
              [
                ['all', false],
                ['any', true]
              ]
            end

            with_them do
              let(:policy_scope) do
                {
                  match_mode: match_mode,
                  compliance_frameworks: [{ id: compliance_framework.id }],
                  projects: {
                    excluding: [{ id: project.id }]
                  }
                }
              end

              it { is_expected.to eq expected_result }
            end
          end
        end

        context 'when non-existing compliance framework is set' do
          let(:policy_scope) do
            {
              compliance_frameworks: [{ id: non_existing_record_id }]
            }
          end

          it { is_expected.to be false }
        end
      end
    end

    context 'when policy is scoped for projects' do
      context 'with including project scope' do
        context 'when included project scope is not matching project id' do
          let(:policy_scope) do
            {
              projects: {
                including: [{ id: non_existing_record_id }]
              }
            }
          end

          it { is_expected.to be false }

          it "triggers an internal event" do
            expect { policy_applicable }.to trigger_internal_events('check_policy_scope_for_security_policy').with(
              project: project,
              additional_properties: { label: 'project' }
            )
          end
        end

        context 'when included project scope is matching project id' do
          let(:policy_scope) do
            {
              projects: {
                including: [{ id: project.id }]
              }
            }
          end

          it { is_expected.to be true }

          context 'when additionally excluding project scope is matching project id' do
            let(:policy_scope) do
              {
                projects: {
                  including: [{ id: project.id }],
                  excluding: [{ id: project.id }]
                }
              }
            end

            it { is_expected.to be false }
          end
        end
      end

      context 'with excluding project scope' do
        context 'when excluding project scope is not matching project id' do
          let(:policy_scope) do
            {
              projects: {
                excluding: [{ id: non_existing_record_id }]
              }
            }
          end

          it { is_expected.to be true }
        end

        context 'when excluding project scope is matching project id' do
          let(:policy_scope) do
            {
              projects: {
                excluding: [{ id: project.id }]
              }
            }
          end

          it { is_expected.to be false }
        end

        context 'when excluding project scope is personal' do
          let(:policy_scope) do
            {
              projects: {
                excluding: [{ type: 'personal' }]
              }
            }
          end

          it { is_expected.to be true }

          context 'and project is personal' do
            let_it_be_with_refind(:project) { create(:project, namespace: user.namespace) }

            it { is_expected.to be false }
          end
        end

        context 'when excluding project scope is archived' do
          let(:policy_scope) do
            {
              projects: {
                excluding: [{ type: 'archived' }]
              }
            }
          end

          it { is_expected.to be true }

          context 'and project is archived' do
            let_it_be_with_refind(:project) { create(:project, :archived, group: group) }

            it { is_expected.to be false }
          end
        end
      end
    end

    context 'when policy is scoped for groups' do
      context 'with including group scope' do
        context 'when included group scope is not matching group id' do
          let(:policy_scope) do
            {
              groups: {
                including: [{ id: non_existing_record_id }]
              }
            }
          end

          it { is_expected.to be false }

          it "triggers an internal event" do
            expect { policy_applicable }.to trigger_internal_events('check_policy_scope_for_security_policy').with(
              project: project,
              additional_properties: { label: 'group' }
            )
          end
        end

        context 'when included group scope is matching project distant ancestor group id' do
          let(:policy_scope) do
            {
              groups: {
                including: [{ id: root_group.id }]
              }
            }
          end

          it { is_expected.to be true }
        end

        context 'when included group scope is matching project direct ancestor group id' do
          let(:policy_scope) do
            {
              groups: {
                including: [{ id: group.id }]
              }
            }
          end

          it { is_expected.to be true }

          context 'when additionally excluding group scope is matching project ancestor group id' do
            let(:policy_scope) do
              {
                groups: {
                  including: [{ id: group.id }],
                  excluding: [{ id: group.id }]
                }
              }
            end

            it { is_expected.to be false }
          end
        end
      end

      context 'with excluding group scope' do
        context 'when excluding group scope is not matching project ancestor group id' do
          let(:policy_scope) do
            {
              groups: {
                excluding: [{ id: non_existing_record_id }]
              }
            }
          end

          it { is_expected.to be true }
        end

        context 'when excluding group scope is matching project ancestor group id' do
          let(:policy_scope) do
            {
              groups: {
                excluding: [{ id: group.id }]
              }
            }
          end

          it { is_expected.to be false }
        end
      end

      context 'with excluding parent group and including subgroup' do
        let(:policy_scope) do
          {
            groups: {
              excluding: [{ id: root_group.id }],
              including: [{ id: group.id }]
            }
          }
        end

        it { is_expected.to be false }
      end

      context 'with excluding subgroup and including parent group' do
        let(:policy_scope) do
          {
            groups: {
              excluding: [{ id: group.id }],
              including: [{ id: root_group.id }]
            }
          }
        end

        it { is_expected.to be false }
      end
    end

    context 'with combined project and group scopes' do
      context 'when project is included but group does not match (different group)' do
        let(:base_policy_scope) do
          {
            projects: { including: [{ id: project.id }] },
            groups: { including: [{ id: other_group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
      end

      context 'when project is excluded but group matches' do
        let(:base_policy_scope) do
          {
            projects: { excluding: [{ id: project.id }] },
            groups: { including: [{ id: group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
      end

      context 'when neither project nor group matches' do
        let(:base_policy_scope) do
          {
            projects: { including: [{ id: -1 }] },
            groups: { including: [{ id: other_group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: false
      end

      context 'when both project and group match' do
        let(:base_policy_scope) do
          {
            projects: { including: [{ id: project.id }] },
            groups: { including: [{ id: group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: true, all_result: true, any_result: true
      end
    end

    context 'with combined compliance_framework, project, and group scopes' do
      let_it_be(:compliance_framework_project_setting) do
        create(:compliance_framework_project_setting,
          project: project,
          compliance_management_framework: compliance_framework)
      end

      context 'when all three scopes match' do
        let(:base_policy_scope) do
          {
            compliance_frameworks: [{ id: compliance_framework.id }],
            projects: { including: [{ id: project.id }] },
            groups: { including: [{ id: group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: true, all_result: true, any_result: true
      end

      context 'when only compliance_framework matches' do
        let(:base_policy_scope) do
          {
            compliance_frameworks: [{ id: compliance_framework.id }],
            projects: { including: [{ id: -1 }] },
            groups: { including: [{ id: other_group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
      end

      context 'when compliance_framework does not match but project and group do' do
        let(:base_policy_scope) do
          {
            compliance_frameworks: [{ id: -1 }],
            projects: { including: [{ id: project.id }] },
            groups: { including: [{ id: group.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
      end
    end

    context 'when policy is scoped for business_impact attributes' do
      it_behaves_like 'scoped security attribute checker',
        scope_key: :business_impact,
        template_type: :business_impact,
        category_name: 'Business Impact',
        attribute_1_name: 'Critical',
        attribute_2_name: 'High'
    end

    context 'when policy is scoped for application attributes' do
      it_behaves_like 'scoped security attribute checker',
        scope_key: :application,
        template_type: :application,
        category_name: 'Application',
        attribute_1_name: 'WebApp',
        attribute_2_name: 'MobileApp'
    end

    context 'when policy is scoped for business_unit attributes' do
      it_behaves_like 'scoped security attribute checker',
        scope_key: :business_unit,
        template_type: :business_unit,
        category_name: 'Business Unit',
        attribute_1_name: 'Engineering',
        attribute_2_name: 'Finance'
    end

    context 'when policy is scoped for exposure attributes' do
      it_behaves_like 'scoped security attribute checker',
        scope_key: :exposure,
        template_type: :exposure,
        category_name: 'Exposure',
        attribute_1_name: 'Internet Facing',
        attribute_2_name: 'Internal Only'
    end

    context 'when policy has multiple security attribute category scopes' do
      let_it_be(:business_impact_category) do
        create(:security_category, namespace: root_group, template_type: :business_impact, name: 'Business Impact')
      end

      let_it_be(:business_impact_attribute) do
        create(:security_attribute, namespace: root_group, security_category: business_impact_category,
          name: 'Critical')
      end

      let_it_be(:application_category) do
        create(:security_category, namespace: root_group, template_type: :application, name: 'Application')
      end

      let_it_be(:application_attribute) do
        create(:security_attribute, namespace: root_group, security_category: application_category, name: 'WebApp')
      end

      let_it_be(:business_unit_category) do
        create(:security_category, namespace: root_group, template_type: :business_unit, name: 'Business Unit')
      end

      let_it_be(:business_unit_attribute) do
        create(:security_attribute, namespace: root_group, security_category: business_unit_category,
          name: 'Engineering')
      end

      let_it_be(:exposure_category) do
        create(:security_category, namespace: root_group, template_type: :exposure, name: 'Exposure')
      end

      let_it_be(:exposure_attribute) do
        create(:security_attribute, namespace: root_group, security_category: exposure_category,
          name: 'Internet Facing')
      end

      let_it_be(:project_business_impact_attribute) do
        create(:project_to_security_attribute, project: project, security_attribute: business_impact_attribute,
          traversal_ids: project.namespace.traversal_ids)
      end

      context 'when business_impact matches but application, business_unit and exposure do not' do
        let(:base_policy_scope) do
          {
            application: { including: [{ id: application_attribute.id }] },
            business_impact: { including: [{ id: business_impact_attribute.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: true
      end

      context 'when all four security attribute category scopes match' do
        let_it_be(:project_application_attribute) do
          create(:project_to_security_attribute, project: project, security_attribute: application_attribute,
            traversal_ids: project.namespace.traversal_ids)
        end

        let_it_be(:project_business_unit_attribute) do
          create(:project_to_security_attribute, project: project, security_attribute: business_unit_attribute,
            traversal_ids: project.namespace.traversal_ids)
        end

        let_it_be(:project_exposure_attribute) do
          create(:project_to_security_attribute, project: project, security_attribute: exposure_attribute,
            traversal_ids: project.namespace.traversal_ids)
        end

        let(:base_policy_scope) do
          {
            application: { including: [{ id: application_attribute.id }] },
            business_impact: { including: [{ id: business_impact_attribute.id }] },
            business_unit: { including: [{ id: business_unit_attribute.id }] },
            exposure: { including: [{ id: exposure_attribute.id }] }
          }
        end

        it_behaves_like 'match_mode expectations', nil_result: true, all_result: true, any_result: true
      end

      it 'issues a single DB query for all security attribute categories regardless of how many are active' do
        policy = {
          policy_scope: {
            application: { including: [{ id: application_attribute.id }] },
            business_impact: { including: [{ id: business_impact_attribute.id }] },
            business_unit: { including: [{ id: business_unit_attribute.id }] },
            exposure: { including: [{ id: exposure_attribute.id }] }
          }
        }

        expect { service.policy_applicable?(policy, configuration: configuration) }
          .to make_queries_matching(/security_attributes.*security_categories/, 1)
      end
    end

    context 'when only some scopes are defined' do
      context 'when only matching project scope is defined' do
        let(:base_policy_scope) { { projects: { including: [{ id: project.id }] } } }

        it_behaves_like 'match_mode expectations', nil_result: true, all_result: true, any_result: true
      end

      context 'when only non-matching project scope is defined' do
        let(:base_policy_scope) { { projects: { including: [{ id: -1 }] } } }

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: false
      end

      context 'when only matching group scope is defined' do
        let(:base_policy_scope) { { groups: { including: [{ id: group.id }] } } }

        it_behaves_like 'match_mode expectations', nil_result: true, all_result: true, any_result: true
      end

      context 'when only non-matching group scope is defined' do
        let(:base_policy_scope) { { groups: { including: [{ id: other_group.id }] } } }

        it_behaves_like 'match_mode expectations', nil_result: false, all_result: false, any_result: false
      end
    end
  end

  describe '#project_security_category_attribute_ids' do
    subject(:attribute_ids) { service.send(:project_security_category_attribute_ids, :business_impact) }

    context 'when project has no security attributes' do
      it 'returns an empty array' do
        expect(attribute_ids).to eq([])
      end
    end

    context 'when project has security attributes' do
      let_it_be(:category) do
        create(:security_category, namespace: root_group, template_type: :business_impact, name: 'Business Impact')
      end

      let_it_be(:attribute) do
        create(:security_attribute, namespace: root_group, security_category: category, name: 'Critical')
      end

      let_it_be(:_project_attribute) do
        create(:project_to_security_attribute, project: project, security_attribute: attribute,
          traversal_ids: project.namespace.traversal_ids)
      end

      context 'when the category exists in the project attributes' do
        it 'returns the attribute ids for that category' do
          expect(attribute_ids).to contain_exactly(attribute.id)
        end
      end

      context 'when the category is not present in the project attributes' do
        it 'returns an empty array' do
          expect(service.send(:project_security_category_attribute_ids, :application)).to eq([])
        end
      end

      it 'memoizes the result and issues only one DB query across multiple calls' do
        expect { 3.times { service.send(:project_security_category_attribute_ids, :business_impact) } }
          .to make_queries_matching(/security_attributes/, 1)
      end
    end
  end

  describe '#policy_applicable?' do
    let_it_be(:configuration) do
      create(:security_orchestration_policy_configuration,
        project: project,
        experiments: { security_attributes_policy_scope: { enabled: true } })
    end

    let(:policy) { { policy_scope: policy_scope } }

    subject(:policy_applicable) { service.policy_applicable?(policy, configuration: configuration) }

    context 'when policy is empty' do
      let(:policy) { {} }

      it { is_expected.to be false }
    end

    it_behaves_like 'policy scope checker'
  end

  describe '#security_policy_applicable?' do
    let(:configuration) do
      create(:security_orchestration_policy_configuration,
        project: project,
        experiments: { security_attributes_policy_scope: { enabled: true } })
    end

    let(:policy) do
      create(:security_policy, scope: policy_scope,
        security_orchestration_policy_configuration: configuration)
    end

    subject(:policy_applicable) { service.security_policy_applicable?(policy) }

    context 'when policy is empty' do
      let(:policy) { nil }

      it { is_expected.to be false }
    end

    it_behaves_like 'policy scope checker'

    context 'when security attribute scope is defined' do
      let_it_be(:category) do
        create(:security_category, namespace: root_group, template_type: :business_impact, name: 'Business Impact')
      end

      let_it_be(:attribute) do
        create(:security_attribute, namespace: root_group, security_category: category, name: 'Critical')
      end

      let_it_be(:other_attribute) do
        create(:security_attribute, namespace: root_group, security_category: category, name: 'High')
      end

      let_it_be(:_project_attribute) do
        create(:project_to_security_attribute, project: project, security_attribute: attribute,
          traversal_ids: project.namespace.traversal_ids)
      end

      let(:policy_scope) { { business_impact: { including: [{ id: other_attribute.id }] } } }

      context 'when the experiment is disabled on the policy configuration' do
        before do
          policy.security_orchestration_policy_configuration
            .update!(experiments: { security_attributes_policy_scope: { enabled: false } })
        end

        it 'ignores the security attribute scope and returns true' do
          is_expected.to be true
        end
      end

      context 'when the experiment is enabled on the policy configuration' do
        before do
          policy.security_orchestration_policy_configuration
            .update!(experiments: { security_attributes_policy_scope: { enabled: true } })
        end

        it 'enforces the security attribute scope and returns false' do
          is_expected.to be false
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(security_attributes_policy_scope: false)
          end

          it 'ignores the security attribute scope and returns true' do
            is_expected.to be true
          end
        end
      end
    end
  end
end
