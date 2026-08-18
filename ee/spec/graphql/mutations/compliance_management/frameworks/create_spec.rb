# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::Frameworks::Create, feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group) }

  let(:params) { valid_params }
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  subject(:mutation_result) { mutation.resolve(**params) }

  describe '#resolve' do
    context 'feature is unlicensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: false)
      end

      it 'does not create a new compliance framework' do
        expect { mutation_result }.not_to change { namespace.compliance_management_frameworks.count }
      end

      it 'returns useful error messages' do
        expect(mutation_result[:errors]).to include('Not permitted to create framework')
      end
    end

    context 'feature is licensed' do
      before do
        stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
      end

      context 'current_user is not group namespace owner' do
        it 'does not create a new compliance framework' do
          expect { mutation_result }.not_to change { namespace.compliance_management_frameworks.count }
        end

        it 'returns useful error messages' do
          expect(mutation_result[:errors]).to include 'Not permitted to create framework'
        end
      end

      context 'current_user is group owner' do
        before_all do
          namespace.add_owner(current_user)
        end

        it 'creates a new compliance framework' do
          expect { mutation_result }.to change { namespace.compliance_management_frameworks.count }.by 1
        end
      end

      context 'current_user is personal namespace owner' do
        let_it_be(:namespace) { create(:user_namespace) }

        let(:current_user) { namespace.owner }

        context 'framework parameters are valid' do
          it 'does not create a new compliance framework' do
            expect { mutation_result }.not_to change { namespace.compliance_management_frameworks.count }
          end
        end

        context 'namespace does not exist' do
          let(:params) { valid_params.merge(namespace_path: 'not_a_path') }

          it 'raises an error' do
            expect { mutation_result }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end

        context 'framework parameters are invalid' do
          subject(:mutation_result) { mutation.resolve(**invalid_color_params) }

          it 'does not create a new compliance framework' do
            expect { mutation_result }.not_to change { namespace.compliance_management_frameworks.count }
          end

          it 'returns useful error messages' do
            expect(mutation_result[:errors]).to include 'Color must be a valid color code'
          end
        end
      end
    end
  end

  private

  def valid_params
    {
      namespace_path: namespace.full_path,
      params: {
        name: 'GDPR',
        description: 'Example description',
        color: '#abc123',
        pipeline_configuration_full_path: '.compliance-gitlab-ci.yml@compliance/hipaa'
      }
    }
  end

  def invalid_color_params
    {
      namespace_path: namespace.full_path,
      params: {
        name: 'GDPR',
        description: 'Example description',
        color: '#notacolor'
      }
    }
  end
end
