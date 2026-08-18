# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::ComponentsFinder, feature_category: :static_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be(:scan) { create(:security_ascp_scan, project: project) }
  let_it_be(:component1) do
    create(:security_ascp_component, project: project, scan: scan, title: 'Auth Module', sub_directory: 'app/auth')
  end

  let_it_be(:component2) do
    create(:security_ascp_component, project: project, scan: scan, title: 'Payment Service',
      sub_directory: 'app/payment')
  end

  let_it_be(:other_project) { create(:project) }
  let_it_be(:other_component) { create(:security_ascp_component, project: other_project, title: 'Other Component') }

  let(:params) { {} }

  subject(:finder) { described_class.new(project: project, params: params) }

  describe '#execute' do
    it 'returns components for the project' do
      expect(finder.execute).to contain_exactly(component1, component2)
    end

    it 'does not return components from other projects' do
      expect(finder.execute).not_to include(other_component)
    end

    context 'when filtering by title' do
      let(:params) { { title: 'Auth' } }

      it 'returns components matching the title' do
        expect(finder.execute).to contain_exactly(component1)
      end

      context 'with case-insensitive search' do
        let(:params) { { title: 'auth' } }

        it 'returns components matching the title' do
          expect(finder.execute).to contain_exactly(component1)
        end
      end

      context 'with partial match' do
        let(:params) { { title: 'Service' } }

        it 'returns components matching the partial title' do
          expect(finder.execute).to contain_exactly(component2)
        end
      end

      context 'with SQL injection attempt' do
        let(:params) { { title: '%' } }

        it 'safely handles wildcard characters' do
          expect(finder.execute).to be_empty
        end
      end
    end

    context 'when filtering by sub_directory' do
      let(:params) { { sub_directory: 'app/auth' } }

      it 'returns components in the specified directory' do
        expect(finder.execute).to contain_exactly(component1)
      end

      context 'with non-matching directory' do
        let(:params) { { sub_directory: 'app/other' } }

        it 'returns empty result' do
          expect(finder.execute).to be_empty
        end
      end
    end

    context 'when combining filters' do
      let(:params) { { title: 'Auth', sub_directory: 'app/auth' } }

      it 'returns components matching all filters' do
        expect(finder.execute).to contain_exactly(component1)
      end
    end
  end
end
