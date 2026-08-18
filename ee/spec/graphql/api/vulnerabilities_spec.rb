# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'vulnerabilities', feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { project.first_owner }
  let_it_be(:vulnerability_1) { create(:vulnerability, project: project) }
  let_it_be(:vulnerability_2) { create(:vulnerability, project: project) }

  let(:field_args) { nil }
  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          name
          vulnerabilities#{field_args} {
            nodes {
              id
            }
            pageInfo {
              endCursor
            }
          }
        }
      }
    )
  end

  let(:vulnerabilities) { execute.dig('data', 'project', 'vulnerabilities') }
  let(:extensions) { execute['extensions'] }

  subject(:execute) { GitlabSchema.execute(query, context: { current_user: user }).as_json }

  before do
    stub_licensed_features(security_dashboard: true, sast_fp_reduction: true)

    # Creating the findings in different order will force the triggers to
    # create the `vulnerability_reads` records in specific order.
    create(:vulnerabilities_finding, vulnerability: vulnerability_2, project: project)
    create(:vulnerabilities_finding, vulnerability: vulnerability_1, project: project)
  end

  describe 'extensions' do
    context 'when the query could use vulnerability identifier filtering' do
      let(:query) do
        %(
          query {
          #{vulnerable.class.name.downcase}(fullPath: "#{vulnerable.full_path}") {
            name
            vulnerabilities { nodes { id } } }})
      end

      before do
        test_vulnerability_limit = 1
        stub_const(
          '::Security::GroupIdentifierSearch::MAX_VULNERABILITY_COUNT_GROUP_SUPPORT',
          test_vulnerability_limit
        )
        allow(::Security::ProjectStatistics).to receive(:sum_vulnerability_count_for_group)
                                                  .with(group).and_return(test_vulnerability_limit + 1)
      end

      context 'when vulnerable is project' do
        let(:vulnerable) { project }

        it { expect(extensions["disabled_filters"]).to eq [] }
      end

      context 'when vulnerable is group' do
        let(:vulnerable) { group }

        it { expect(extensions["disabled_filters"]).to match_array %w[identifier_name] }
      end

      context 'when the vulnerability type is not in the query' do
        let(:query) { %(query { group(fullPath: "#{group.full_path}") { name } }) }

        it "does not calculate disabled vulnerability filters" do
          expect(extensions).to be_nil
        end
      end
    end
  end

  describe 'nodes' do
    let(:nodes) { vulnerabilities['nodes'] }
    let(:vulnerability_ids) { nodes.map { |node| node['id'] } }

    describe 'ordering' do
      it 'returns the records in correct order' do
        expect(vulnerability_ids).to eq([vulnerability_2.to_global_id.to_s, vulnerability_1.to_global_id.to_s])
      end
    end

    describe 'pagination' do
      let(:cursor_attributes) { { severity: vulnerability_2.severity, vulnerability_id: vulnerability_2.id.to_s } }
      let(:end_cursor) { Base64.encode64(cursor_attributes.to_json).chomp }
      let(:field_args) { "(after: \"#{end_cursor}\")" }

      it 'returns the correct record' do
        expect(vulnerability_ids).to match_array(vulnerability_1.to_global_id.to_s)
      end
    end
  end

  describe 'pageInfo' do
    describe 'endCursor' do
      let(:end_cursor_hash) do
        vulnerabilities.dig('pageInfo', 'endCursor')
                       .then { |end_cursor| Base64.decode64(end_cursor) }
                       .then { |decoded_end_cursor| Gitlab::Json.parse(decoded_end_cursor) }
      end

      it 'encodes last `vulnerability_id` into the `endCursor`' do
        expect(end_cursor_hash).to include('vulnerability_id' => vulnerability_1.id.to_s)
      end
    end
  end
end
