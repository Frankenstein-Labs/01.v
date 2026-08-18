# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Projects::UpdateComplianceFrameworks, feature_category: :compliance_management do
  include GraphqlHelpers
  let_it_be(:group) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, :sox, namespace: group) }
  let_it_be(:project) { create(:project, :repository, :with_compliance_framework, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:existing_framework) { project.compliance_management_frameworks.first }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  subject do
    mutation.resolve(project_id: GitlabSchema.id_from_object(project),
      compliance_framework_ids: [GitlabSchema.id_from_object(existing_framework),
        GitlabSchema.id_from_object(framework)])
  end

  shared_examples "the user cannot update the project's compliance framework" do
    it 'raises an exception' do
      expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
    end
  end

  shared_examples "the user can update compliance frameworks of the project" do
    it 'updates the compliance frameworks to the project' do
      expect { subject }.to change { project.reload.compliance_management_frameworks }
                              .from([existing_framework]).to(match_array([framework, existing_framework]))
    end

    it 'returns the project that was updated' do
      expect(subject).to include(project: project)
    end
  end

  describe '#resolve' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(compliance_framework: true, custom_compliance_frameworks: true)
      end

      context 'when current_user is a project maintainer' do
        before_all do
          project.add_maintainer(current_user)
        end

        it_behaves_like "the user cannot update the project's compliance framework"
      end

      context 'when current_user is a project owner' do
        before_all do
          group.add_owner(current_user)
          project.add_owner(current_user)
        end

        it_behaves_like "the user can update compliance frameworks of the project"

        context 'when framework id is invalid' do
          subject(:resolve) do
            mutation.resolve(project_id: GitlabSchema.id_from_object(project),
              compliance_framework_ids: ["gid://gitlab/ComplianceManagement::Framework/#{non_existing_record_id}"])
          end

          it 'returns Argument error' do
            expect { resolve }.to raise_error(Gitlab::Graphql::Errors::ArgumentError,
              format(_("Framework id(s) [%{record_id}] are invalid."), record_id: non_existing_record_id))
          end
        end
      end
    end

    context 'when feature is unlicensed' do
      before do
        stub_licensed_features(compliance_framework: false)
      end

      it_behaves_like "the user cannot update the project's compliance framework"
    end
  end
end
