# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Items::BaseCreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }

  let(:user) { maintainer }
  let(:params) do
    {
      name: 'Test Item',
      description: 'Test Description',
      public: true
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  before do
    enable_ai_catalog
  end

  describe '#execute' do
    describe 'NotImplementedError methods' do
      describe '#definition' do
        it 'raises NotImplementedError' do
          expect { service.send(:definition) }.to raise_error(NotImplementedError)
        end
      end

      describe '#item_type' do
        it 'raises NotImplementedError' do
          expect { service.send(:item_type) }.to raise_error(NotImplementedError)
        end
      end

      describe '#schema_version' do
        it 'raises NotImplementedError' do
          expect { service.send(:schema_version) }.to raise_error(NotImplementedError)
        end
      end
    end
  end
end
