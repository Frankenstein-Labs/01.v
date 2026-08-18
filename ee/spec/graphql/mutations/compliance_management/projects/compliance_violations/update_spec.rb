# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::Projects::ComplianceViolations::Update,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:compliance_violation) { create(:project_compliance_violation, project: project, namespace: group) }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  before_all do
    group.add_owner(current_user)
  end

  describe '#resolve' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: true)
      end

      context 'when user is authorized' do
        context 'when updating status successfully' do
          it 'updates the violation status' do
            result = mutation.resolve(id: compliance_violation.to_global_id, status: 'in_review')

            expect(result[:compliance_violation].status).to eq('in_review')
            expect(result[:errors]).to be_empty
          end

          it 'persists the status change' do
            mutation.resolve(id: compliance_violation.to_global_id, status: 'resolved')

            expect(compliance_violation.reload.status).to eq('resolved')
          end
        end

        context 'when validation fails' do
          before do
            allow_next_instance_of(ComplianceManagement::Projects::ComplianceViolation) do |violation|
              allow(violation).to receive_messages(update: false,
                errors: instance_double(ActiveModel::Errors, full_messages: ['Status is invalid']))
            end
          end

          it 'returns validation errors' do
            expect do
              mutation.resolve(id: compliance_violation.to_global_id, status: 'invalid_status')
            end.to raise_error(ArgumentError)
          end
        end
      end

      context 'when user is not authorized' do
        before_all do
          group.add_maintainer(current_user)
        end

        it 'raises authorization error' do
          expect { mutation.resolve(id: compliance_violation.to_global_id, status: 'in_review') }
            .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(group_level_compliance_violations_report: false)
      end

      it 'raises authorization error' do
        expect { mutation.resolve(id: compliance_violation.to_global_id, status: 'in_review') }
          .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
