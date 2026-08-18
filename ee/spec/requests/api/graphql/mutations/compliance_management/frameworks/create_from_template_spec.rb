# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a Compliance Framework from Template', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:mutation) do
    graphql_mutation(
      :create_compliance_framework_from_template,
      namespace_path: namespace.full_path,
      template_id: "gid://gitlab/ComplianceManagement::Frameworks::TemplateRegistry::Template/soc2"
    )
  end

  subject(:execute_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:create_compliance_framework_from_template)
  end

  shared_examples 'a mutation that creates a compliance framework from template' do
    it 'creates a new compliance framework' do
      expect { execute_mutation }.to change { namespace.compliance_management_frameworks.count }.by 1
    end

    it 'returns the newly created framework', :aggregate_failures do
      execute_mutation

      framework = mutation_response['framework']
      expect(framework['name']).to eq 'SOC 2'
      expect(framework['color']).to eq '#D03E38'
    end

    it 'persists the framework with the expected values', :aggregate_failures do
      execute_mutation

      framework = namespace.compliance_management_frameworks.last
      expect(framework.name).to eq 'SOC 2'
      expect(framework.color).to eq '#D03E38'
      expect(framework.description).to be_present
      expect(framework.namespace).to eq namespace
      expect(framework.template_id).to eq 'soc2'
      expect(framework.template_version).to eq 1
    end

    it 'creates requirements' do
      expect { execute_mutation }.to change {
        ComplianceManagement::ComplianceFramework::ComplianceRequirement.count
      }.by(9)
    end
  end

  context 'when framework feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when current_user is group owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :create_compliance_framework do
        before do
          # Creating a framework from a template also creates its requirements
          # and controls, which exceeds the default query threshold.
          allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(300)
        end

        let(:user) { current_user }
        let(:boundary_object) { namespace }
        let(:mutation) do
          graphql_mutation(
            :create_compliance_framework_from_template,
            {
              namespace_path: namespace.full_path,
              template_id: "gid://gitlab/ComplianceManagement::Frameworks::TemplateRegistry::Template/soc2"
            },
            'errors'
          )
        end

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it_behaves_like 'a mutation that creates a compliance framework from template'

      context 'with overrides' do
        let(:mutation) do
          graphql_mutation(
            :create_compliance_framework_from_template,
            namespace_path: namespace.full_path,
            template_id: "gid://gitlab/ComplianceManagement::Frameworks::TemplateRegistry::Template/soc2",
            name: 'Custom SOC 2',
            description: 'Custom description',
            color: '#ABC123'
          )
        end

        it 'creates a framework with overridden values', :aggregate_failures do
          execute_mutation

          framework = mutation_response['framework']
          expect(framework['name']).to eq 'Custom SOC 2'
          expect(framework['description']).to eq 'Custom description'
          expect(framework['color']).to eq '#ABC123'
        end
      end

      context 'with non-existent template' do
        let(:mutation) do
          graphql_mutation(
            :create_compliance_framework_from_template,
            namespace_path: namespace.full_path,
            template_id: "gid://gitlab/ComplianceManagement::Frameworks::TemplateRegistry::Template/nonexistent"
          )
        end

        before do
          post_graphql_mutation(mutation, current_user: current_user)
        end

        it_behaves_like 'a mutation that returns errors in the response',
          errors: ['Template not found']
      end
    end

    context 'when current_user is not a group owner' do
      before_all do
        namespace.add_maintainer(current_user)
      end

      it 'does not create a new compliance framework' do
        expect { execute_mutation }.not_to change { namespace.compliance_management_frameworks.count }
      end

      it 'returns a resource not available error' do
        execute_mutation

        expect(graphql_errors).to include(
          a_hash_including('message' => include("you don't have permission"))
        )
      end
    end
  end
end
