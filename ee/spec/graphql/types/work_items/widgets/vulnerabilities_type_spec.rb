# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::Widgets::VulnerabilitiesType, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let(:fields) do
    %i[type related_vulnerabilities]
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetVulnerabilities') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  describe "related vulnerabilities" do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:vulnerabilities) { create_list(:vulnerability, 2, project: project) }
    let_it_be(:issue) { create(:issue, project: project, related_vulnerabilities: vulnerabilities) }

    let(:query) do
      %(
        query {
          namespace(fullPath: "#{project.full_path}") {
            workItem(iid: "#{issue.iid}") {
              id
              widgets {
                ... on WorkItemWidgetVulnerabilities {
                  type
                  relatedVulnerabilities {
                    nodes {
                      title
                    }
                    count
                  }
                }
              }
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: current_user }).as_json }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    shared_examples_for 'does not include related vulnerabilities' do
      it "does not return related vulnerabilities" do
        related_vulnerabilities = get_related_vulnerabilities(subject)['nodes']
        expect(related_vulnerabilities).to be_empty
      end
    end

    shared_examples_for 'includes related vulnerabilities' do
      it "returns related vulnerabilities" do
        related_vulnerabilities = get_related_vulnerabilities(subject)
        vulnerability_titles = related_vulnerabilities['nodes'].pluck("title")

        expect(vulnerability_titles).to match_array(vulnerabilities.map(&:title))
        expect(related_vulnerabilities['count']).to eq(vulnerabilities.count)
      end
    end

    context 'when user signed in' do
      let_it_be(:current_user) { user }

      context 'and user is not a member of the project' do
        it_behaves_like 'does not include related vulnerabilities'
      end

      context 'and user is a member of the project' do
        before_all do
          project.add_developer(user)
        end

        it_behaves_like 'includes related vulnerabilities'

        context 'and the issue does not have any related vulnerabilities' do
          let_it_be(:issue) { create(:issue, project: project, related_vulnerabilities: []) }

          it_behaves_like 'does not include related vulnerabilities'
        end
      end
    end

    context 'when user is not signed in' do
      let_it_be(:current_user) { nil }

      it_behaves_like 'does not include related vulnerabilities'
    end

    def get_related_vulnerabilities(response)
      widgets = graphql_dig_at(response.to_h, 'data', 'namespace', 'workItem', 'widgets')
      widgets.find { |widget| widget['type'] == "VULNERABILITIES" }['relatedVulnerabilities']
    end
  end
end
