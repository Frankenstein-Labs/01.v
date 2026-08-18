# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyScopeFetcher, :aggregate_failures, feature_category: :security_policy_management do
  let_it_be_with_refind(:namespace) { create(:group) }

  let_it_be_with_refind(:namespace1) { create(:group, parent: namespace) }
  let_it_be_with_refind(:namespace2) { create(:group, parent: namespace) }

  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, namespace: namespace, project: nil)
  end

  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }

  let_it_be_with_refind(:framework1) { create(:compliance_framework, namespace: namespace, name: 'GDPR') }
  let_it_be_with_refind(:framework2) { create(:compliance_framework, namespace: namespace, name: 'SOX') }

  let(:policy_scope) do
    {
      compliance_frameworks: [
        { id: framework1.id },
        { id: framework2.id }
      ],
      projects: {
        including: [
          { id: project1.id }
        ],
        excluding: [
          { id: project2.id }
        ]
      },
      groups: {
        including: [
          { id: namespace1.id }
        ],
        excluding: [
          { id: namespace2.id }
        ]
      }
    }
  end

  let_it_be_with_refind(:container) { namespace }
  let(:current_user) { namespace.owner }

  subject(:service) do
    described_class.new(policy_scope: policy_scope, container: container, current_user: current_user)
  end

  shared_examples 'returns policy_scope' do |fetch_all_frameworks: false|
    context 'when compliance_frameworks, projects and groups are present' do
      it 'returns the compliance_frameworks and projects' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1, framework2)
        expect(response[:including_projects]).to contain_exactly(project1)
        expect(response[:excluding_projects]).to contain_exactly(project2)
        expect(response[:including_groups]).to contain_exactly(namespace1)
        expect(response[:excluding_groups]).to contain_exactly(namespace2)
      end
    end

    context 'when policy_scope is empty' do
      let(:policy_scope) { nil }

      it 'returns empty result' do
        response = service.execute

        expect(response[:compliance_frameworks]).to be_empty
        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
        expect(response[:match_mode]).to eq('all')
      end
    end

    context 'when projects are empty and groups are missing' do
      let(:policy_scope) do
        {
          compliance_frameworks: [
            { id: framework1.id },
            { id: framework2.id }
          ],
          projects: {
            including: [],
            excluding: []
          }
        }
      end

      it 'returns the compliance_frameworks' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1, framework2)
        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
        expect(response[:match_mode]).to eq('all')
      end
    end

    context 'when groups are empty and projects are missing' do
      let(:policy_scope) do
        {
          compliance_frameworks: [
            { id: framework1.id },
            { id: framework2.id }
          ],
          groups: {
            including: [],
            excluding: []
          }
        }
      end

      it 'returns the compliance_frameworks' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1, framework2)
        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
        expect(response[:match_mode]).to eq('all')
      end
    end

    context 'when compliance framework is not associated with the namespace' do
      let_it_be(:framework) { create(:compliance_framework) }
      let(:policy_scope) do
        {
          compliance_frameworks: [{ id: framework.id }],
          projects: { including: [], excluding: [] }
        }
      end

      if fetch_all_frameworks
        it 'returns the compliance_frameworks' do
          response = service.execute

          expect(response[:compliance_frameworks]).to contain_exactly(framework)
        end
      else
        it 'returns empty compliance frameworks' do
          response = service.execute

          expect(response[:compliance_frameworks]).to be_empty
        end
      end

      it 'returns empty projects and groups' do
        response = service.execute

        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
        expect(response[:match_mode]).to eq('all')
      end
    end

    context 'when projects are not associated with the namespace' do
      let_it_be(:project1) { create(:project) }
      let_it_be(:project2) { create(:project) }
      let(:policy_scope) do
        {
          compliance_frameworks: [{ id: framework1.id }],
          projects: { including: [{ id: project1.id }], excluding: [{ id: project2.id }] }
        }
      end

      it 'still returns associated projects' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1)
        expect(response[:including_projects]).to contain_exactly(project1)
        expect(response[:excluding_projects]).to contain_exactly(project2)
        expect(response[:match_mode]).to eq('all')
      end
    end

    context 'when groups are not associated with the namespace' do
      let(:policy_scope) do
        {
          compliance_frameworks: [],
          groups: { including: [{ id: namespace1.id }], excluding: [{ id: namespace2.id }] }
        }
      end

      it 'still returns associated projects' do
        response = service.execute

        expect(response[:compliance_frameworks]).to be_empty
        expect(response[:including_groups]).to contain_exactly(namespace1)
        expect(response[:excluding_groups]).to contain_exactly(namespace2)
      end
    end
  end

  shared_examples 'setting excluding_personal_projects to false' do
    it 'sets excluding_personal_projects to false' do
      response = service.execute

      expect(response[:excluding_personal_projects]).to be false
    end
  end

  shared_examples 'setting excluding_archived_projects to false' do
    it 'sets excluding_archived_projects to false' do
      response = service.execute

      expect(response[:excluding_archived_projects]).to be false
    end
  end

  shared_examples 'scoped security attributes' do |scope_key:, template_type:, including_key:, excluding_key:,
    attribute_1_name:, attribute_2_name:|

    let_it_be(:category) do
      create(:security_category, namespace: namespace, template_type: template_type, name: template_type.to_s.humanize)
    end

    let_it_be(:attribute_1) do
      create(:security_attribute, namespace: namespace, security_category: category, name: attribute_1_name)
    end

    let_it_be(:attribute_2) do
      create(:security_attribute, namespace: namespace, security_category: category, name: attribute_2_name)
    end

    context 'when including and excluding are present' do
      let(:policy_scope) do
        { scope_key => { including: [{ id: attribute_1.id }], excluding: [{ id: attribute_2.id }] } }
      end

      it 'returns including and excluding attributes' do
        response = service.execute

        expect(response[including_key]).to contain_exactly(attribute_1)
        expect(response[excluding_key]).to contain_exactly(attribute_2)
      end
    end

    context 'when scope is not defined' do
      let(:policy_scope) { { compliance_frameworks: [{ id: framework1.id }] } }

      it 'returns empty arrays' do
        response = service.execute

        expect(response[including_key]).to be_empty
        expect(response[excluding_key]).to be_empty
      end
    end

    context 'when attribute belongs to a different namespace' do
      let_it_be(:other_namespace) { create(:group) }

      let_it_be(:other_category) do
        create(:security_category, namespace: other_namespace, template_type: template_type,
          name: template_type.to_s.humanize)
      end

      let_it_be(:other_attribute) do
        create(:security_attribute, namespace: other_namespace, security_category: other_category,
          name: attribute_1_name)
      end

      let_it_be(:other_attribute_2) do
        create(:security_attribute, namespace: other_namespace, security_category: other_category,
          name: attribute_2_name)
      end

      let(:policy_scope) do
        { scope_key => { including: [{ id: other_attribute.id }], excluding: [{ id: other_attribute_2.id }] } }
      end

      it 'does not return attributes from other namespaces' do
        response = service.execute

        expect(response[including_key]).to be_empty
        expect(response[excluding_key]).to be_empty
      end
    end

    context 'when security_attributes_policy_scope feature flag is disabled' do
      before do
        stub_feature_flags(security_attributes_policy_scope: false)
      end

      let(:policy_scope) { { scope_key => { including: [{ id: attribute_1.id }] } } }

      it 'returns empty arrays' do
        response = service.execute

        expect(response[including_key]).to be_empty
        expect(response[excluding_key]).to be_empty
      end
    end
  end

  describe '#execute' do
    context 'when container is a group' do
      it_behaves_like 'returns policy_scope'
    end

    context 'when container is a project' do
      let_it_be_with_refind(:container) { create(:project, namespace: namespace) }

      it_behaves_like 'returns policy_scope'
    end

    context 'when container is a compliance_framework' do
      let_it_be_with_refind(:container) { framework1 }

      it_behaves_like 'returns policy_scope'
    end

    context 'when container is a nil' do
      let_it_be_with_refind(:container) { nil }

      context 'when on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        context 'when compliance framework is not associated with the namespace' do
          let_it_be(:framework) { create(:compliance_framework) }
          let(:policy_scope) do
            {
              compliance_frameworks: [{ id: framework.id }],
              projects: { including: [], excluding: [] }
            }
          end

          it 'returns empty compliance frameworks' do
            response = service.execute

            expect(response[:compliance_frameworks]).to be_empty
          end

          it 'returns empty projects and groups' do
            response = service.execute

            expect(response[:including_projects]).to be_empty
            expect(response[:excluding_projects]).to be_empty
            expect(response[:including_groups]).to be_empty
            expect(response[:excluding_groups]).to be_empty
            expect(response[:match_mode]).to eq('all')
          end
        end
      end

      context 'when on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it_behaves_like 'returns policy_scope', fetch_all_frameworks: true
      end
    end

    describe "excluding_personal_projects" do
      context 'when excluding personal projects' do
        let(:policy_scope) do
          {
            projects: {
              excluding: [
                { id: project1.id, type: 'personal' },
                { id: project2.id }
              ]
            }
          }
        end

        it 'sets excluding_personal_projects to true' do
          response = service.execute

          expect(response[:excluding_personal_projects]).to be true
        end
      end

      context 'when not excluding personal projects' do
        let(:policy_scope) do
          {
            projects: {
              excluding: [
                { id: project1.id },
                { id: project2.id }
              ]
            }
          }
        end

        it_behaves_like 'setting excluding_personal_projects to false'
      end

      context 'when projects excluding is empty' do
        let(:policy_scope) do
          {
            projects: {
              excluding: []
            }
          }
        end

        it_behaves_like 'setting excluding_personal_projects to false'
      end

      context 'when projects excluding is nil' do
        let(:policy_scope) do
          {
            projects: {
              including: [{ id: project1.id }]
            }
          }
        end

        it_behaves_like 'setting excluding_personal_projects to false'
      end

      context 'when policy_scope has no projects key' do
        let(:policy_scope) do
          {
            compliance_frameworks: [{ id: framework1.id }]
          }
        end

        it_behaves_like 'setting excluding_personal_projects to false'
      end
    end

    describe "excluding_archived_projects" do
      context 'when excluding archived projects' do
        let(:policy_scope) do
          {
            projects: {
              excluding: [
                { id: project1.id, type: 'archived' },
                { id: project2.id }
              ]
            }
          }
        end

        it 'sets excluding_archived_projects to true' do
          response = service.execute

          expect(response[:excluding_archived_projects]).to be true
        end
      end

      context 'when not excluding archived projects' do
        let(:policy_scope) do
          {
            projects: {
              excluding: [
                { id: project1.id },
                { id: project2.id }
              ]
            }
          }
        end

        it_behaves_like 'setting excluding_archived_projects to false'
      end

      context 'when projects excluding is empty' do
        let(:policy_scope) do
          {
            projects: {
              excluding: []
            }
          }
        end

        it_behaves_like 'setting excluding_archived_projects to false'
      end

      context 'when projects excluding is nil' do
        let(:policy_scope) do
          {
            projects: {
              including: [{ id: project1.id }]
            }
          }
        end

        it_behaves_like 'setting excluding_archived_projects to false'
      end

      context 'when policy_scope has no projects key' do
        let(:policy_scope) do
          {
            compliance_frameworks: [{ id: framework1.id }]
          }
        end

        it_behaves_like 'setting excluding_archived_projects to false'
      end
    end

    describe 'excluding both personal and archived projects' do
      let(:policy_scope) do
        {
          projects: {
            excluding: [
              { type: 'personal' },
              { type: 'archived' }
            ]
          }
        }
      end

      it 'sets both excluding flags to true' do
        response = service.execute

        expect(response[:excluding_personal_projects]).to be true
        expect(response[:excluding_archived_projects]).to be true
      end
    end

    describe 'business_impact attributes' do
      it_behaves_like 'scoped security attributes',
        scope_key: :business_impact,
        template_type: :business_impact,
        including_key: :including_business_impact_attributes,
        excluding_key: :excluding_business_impact_attributes,
        attribute_1_name: 'Critical',
        attribute_2_name: 'High'
    end

    describe 'application attributes' do
      it_behaves_like 'scoped security attributes',
        scope_key: :application,
        template_type: :application,
        including_key: :including_application_attributes,
        excluding_key: :excluding_application_attributes,
        attribute_1_name: 'WebApp',
        attribute_2_name: 'MobileApp'
    end

    describe 'business_unit attributes' do
      it_behaves_like 'scoped security attributes',
        scope_key: :business_unit,
        template_type: :business_unit,
        including_key: :including_business_unit_attributes,
        excluding_key: :excluding_business_unit_attributes,
        attribute_1_name: 'Engineering',
        attribute_2_name: 'Finance'
    end

    describe 'exposure attributes' do
      it_behaves_like 'scoped security attributes',
        scope_key: :exposure,
        template_type: :exposure,
        including_key: :including_exposure_attributes,
        excluding_key: :excluding_exposure_attributes,
        attribute_1_name: 'Internet Facing',
        attribute_2_name: 'Internal Only'
    end

    describe 'match_mode' do
      context 'when match_mode is not specified' do
        let(:policy_scope) do
          {
            compliance_frameworks: [{ id: framework1.id }]
          }
        end

        it 'defaults to all' do
          response = service.execute

          expect(response[:match_mode]).to eq('all')
        end
      end

      context 'when match_mode is set to all' do
        let(:policy_scope) do
          {
            match_mode: 'all',
            compliance_frameworks: [{ id: framework1.id }]
          }
        end

        it 'returns all' do
          response = service.execute

          expect(response[:match_mode]).to eq('all')
        end
      end

      context 'when match_mode is set to any' do
        let(:policy_scope) do
          {
            match_mode: 'any',
            compliance_frameworks: [{ id: framework1.id }]
          }
        end

        it 'returns any' do
          response = service.execute

          expect(response[:match_mode]).to eq('any')
        end
      end

      context 'when policy_scope is nil' do
        let(:policy_scope) { nil }

        it 'defaults to all' do
          response = service.execute

          expect(response[:match_mode]).to eq('all')
        end
      end
    end
  end
end
