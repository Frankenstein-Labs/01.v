# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::TrackedRefType, feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  before_all { project.add_developer(user) }

  specify { expect(described_class).to require_graphql_authorizations(:read_security_project_tracked_ref) }

  describe 'custom field resolvers' do
    let_it_be(:tracked_ref) { create(:security_project_tracked_context, :tracked, project: project) }
    let(:type_instance) { described_class.send(:new, tracked_ref, {}) }

    describe '#state' do
      it 'uses method delegation to object state' do
        expect(tracked_ref.state).to eq(Security::ProjectTrackedContext::STATES[:tracked])
      end

      context 'with different state values' do
        where(:state_value, :description) do
          Security::ProjectTrackedContext::STATES[:tracked]   | 'tracked state'
          Security::ProjectTrackedContext::STATES[:untracked] | 'untracked state'
        end

        with_them do
          it "correctly returns #{params[:description]}" do
            allow(tracked_ref).to receive(:state).and_return(state_value)

            expect(tracked_ref.state).to eq(state_value)
          end
        end
      end
    end

    describe '#vulnerabilities_count' do
      let_it_be(:expected_reads) do
        create_list(:vulnerability_read, 5, project: project, tracked_context: tracked_ref)
      end

      let_it_be(:other_reads) do
        create_list(:vulnerability_read, 5)
      end

      it 'returns count of vulnerability reads' do
        expect(type_instance.vulnerabilities_count).to eq(expected_reads.count)
      end
    end
  end

  describe 'connection type' do
    it 'uses CountableConnectionType for pagination with count' do
      expect(described_class.connection_type_class).to eq(Types::CountableConnectionType)
    end
  end

  describe 'field call count limits' do
    let(:call_count_limit) { described_class::MAX_GITALY_FIELD_CALLS }

    it 'limits commit field calls' do
      extension = described_class.fields['commit'].extensions.find do |ext|
        ext.is_a?(::Gitlab::Graphql::Limit::FieldCallCount)
      end

      expect(extension).to be_present
      expect(extension.options[:limit]).to eq(call_count_limit)
    end

    it 'limits isProtected field calls' do
      extension = described_class.fields['isProtected'].extensions.find do |ext|
        ext.is_a?(::Gitlab::Graphql::Limit::FieldCallCount)
      end

      expect(extension).to be_present
      expect(extension.options[:limit]).to eq(call_count_limit)
    end
  end
end
