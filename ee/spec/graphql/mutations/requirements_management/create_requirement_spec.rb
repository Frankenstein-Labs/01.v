# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::RequirementsManagement::CreateRequirement, feature_category: :requirements_management do
  include GraphqlHelpers
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    shared_examples 'requirements not available' do
      it 'raises a not accessible error' do
        expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    subject do
      mutation.resolve(
        project_path: project.full_path,
        title: 'foo',
        description: 'some desc'
      )
    end

    it_behaves_like 'requirements not available'

    context 'when the user can create requirements' do
      before_all do
        project.add_developer(current_user)
      end

      context 'when requirements feature is available' do
        before do
          stub_licensed_features(requirements: true)
        end

        it 'creates new requirement' do
          expect(subject[:requirement].title).to eq('foo')
          expect(subject[:requirement].description).to eq('some desc')
          expect(subject[:errors]).to be_empty
        end
      end

      context 'when requirements feature is disabled' do
        before do
          stub_licensed_features(requirements: false)
        end

        it_behaves_like 'requirements not available'
      end
    end
  end
end
