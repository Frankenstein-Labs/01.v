# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a list of compliance frameworks for a namespace', feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: namespace) }
  let_it_be(:compliance_framework_1) do
    create(:compliance_framework, namespace: namespace, name: 'Test1', updated_at: 1.day.ago)
  end

  let_it_be(:compliance_framework_2) do
    create(:compliance_framework, namespace: namespace, name: 'Test2', updated_at: 5.days.ago)
  end

  let(:path) { %i[namespace compliance_frameworks nodes] }

  let!(:query) do
    graphql_query_for(
      :namespace, { full_path: namespace.full_path }, query_nodes(:compliance_frameworks)
    )
  end

  before do
    stub_licensed_features(custom_compliance_frameworks: true)
  end

  context 'when authenticated as the top-level namespace owner' do
    before_all do
      namespace.add_owner(current_user)
    end

    it 'returns the groups compliance frameworks' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(*path)).to contain_exactly(
        a_graphql_entity_for(compliance_framework_1),
        a_graphql_entity_for(compliance_framework_2)
      )
    end

    context 'and there is no configured csp' do
      it 'returns the groups compliance frameworks' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(*path)).to contain_exactly(
          a_graphql_entity_for(compliance_framework_1),
          a_graphql_entity_for(compliance_framework_2)
        )
      end
    end

    context 'and a csp group is configured' do
      let_it_be(:csp_namespace) { create(:group, organization: namespace.organization) }

      let_it_be(:csp_compliance_framework_1) do
        create(:compliance_framework, namespace: csp_namespace, name: 'CSP Test1', updated_at: 1.day.ago)
      end

      let_it_be(:csp_compliance_framework_2) do
        create(:compliance_framework, namespace: csp_namespace, name: 'CSP Test2', updated_at: 5.days.ago)
      end

      before do
        create(:security_policy_settings, organization: namespace.organization, csp_namespace: csp_namespace)
      end

      it 'returns the groups compliance frameworks alongside the CSP frameworks' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(*path)).to contain_exactly(
          a_graphql_entity_for(csp_compliance_framework_1),
          a_graphql_entity_for(csp_compliance_framework_2),
          a_graphql_entity_for(compliance_framework_1),
          a_graphql_entity_for(compliance_framework_2)
        )
      end
    end

    context 'when querying frameworks with nil arguments' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: namespace.full_path },
          query_nodes(:compliance_frameworks, nil, args: {
            id: nil,
            ids: nil
          })
        )
      end

      it 'returns the groups compliance frameworks' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(*path)).to contain_exactly(
          a_graphql_entity_for(compliance_framework_1),
          a_graphql_entity_for(compliance_framework_2)
        )
      end
    end

    context 'when querying a specific framework ID' do
      let(:query) do
        graphql_query_for(
          :namespace,
          { full_path: namespace.full_path },
          query_nodes(:compliance_frameworks, nil, args: { id: global_id_of(compliance_framework_1) })
        )
      end

      it 'returns only a single compliance framework' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :complianceFrameworks, :nodes))
          .to contain_exactly(a_graphql_entity_for(compliance_framework_1))
      end
    end

    context 'when querying multiple framework IDs' do
      before do
        create(:compliance_framework, namespace: namespace, name: 'Test 3')
      end

      let(:query) do
        graphql_query_for(
          :namespace, { full_path: namespace.full_path },
          query_nodes(:compliance_frameworks, nil, args: {
            ids: [global_id_of(compliance_framework_1), global_id_of(compliance_framework_2)]
          })
        )
      end

      it 'returns only matching compliance framework' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :complianceFrameworks, :nodes)).to(
          contain_exactly(a_graphql_entity_for(compliance_framework_1), a_graphql_entity_for(compliance_framework_2))
        )
      end
    end

    context 'when sorting' do
      where(:sort_enum, :expected_order) do
        :NAME_ASC        | %w[Test1 Test2]
        :NAME_DESC       | %w[Test2 Test1]
        :UPDATED_AT_ASC  | %w[Test2 Test1]
        :UPDATED_AT_DESC | %w[Test1 Test2]
      end

      with_them do
        let(:query) do
          graphql_query_for(
            :namespace, { full_path: namespace.full_path },
            query_nodes(:compliance_frameworks, nil, args: {
              sort: sort_enum
            })
          )
        end

        it "sorts frameworks by #{params[:sort_enum]}" do
          post_graphql(query, current_user: current_user)

          framework_names_list = graphql_data_at(:namespace, :complianceFrameworks, :nodes)
            .pluck('name')

          expect(framework_names_list).to eq(expected_order)
        end
      end
    end

    context 'when querying frameworks with both id and ids arguments' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: namespace.full_path },
          query_nodes(:compliance_frameworks, nil, args: {
            id: global_id_of(compliance_framework_1),
            ids: [global_id_of(compliance_framework_1), global_id_of(compliance_framework_2)]
          })
        )
      end

      it 'returns only a single compliance framework with the matching id' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(:namespace, :complianceFrameworks, :nodes)).to(
          contain_exactly(a_graphql_entity_for(compliance_framework_1))
        )
      end
    end

    context 'when querying an invalid object ID' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: namespace.full_path }, query_nodes(:compliance_frameworks, nil, args: args)
        )
      end

      before do
        post_graphql(query, current_user: current_user)
      end

      context 'when querying by id' do
        let(:args) { { id: global_id_of(namespace) } }

        it 'returns an error message' do
          expect(graphql_errors).to contain_exactly(include(
            'message' => "\"#{global_id_of(namespace)}\" does not represent an instance of " \
              "ComplianceManagement::Framework"
          ))
        end
      end

      context 'when querying by ids' do
        let(:args) { { ids: [global_id_of(current_user), global_id_of(namespace)] } }

        it 'returns an error message for the first encountered error' do
          expect(graphql_errors).to contain_exactly(include(
            'message' => "\"#{global_id_of(current_user)}\" does not represent an instance of " \
              "ComplianceManagement::Framework"
          ))
        end
      end
    end

    context 'when querying a specific framework that current_user has no access to' do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: namespace.full_path }, query_nodes(:compliance_frameworks, nil, args: args)
        )
      end

      before do
        post_graphql(query, current_user: current_user)
      end

      context 'when querying by id' do
        let(:args) { { id: global_id_of(create(:compliance_framework)) } }

        it 'does not return the framework' do
          expect(graphql_data_at(:namespace, :complianceFrameworks, :nodes)).to be_empty
        end
      end

      context 'when querying by ids' do
        let(:args) do
          { ids: [global_id_of(create(:compliance_framework)), global_id_of(create(:compliance_framework))] }
        end

        it 'does not return the frameworks' do
          expect(graphql_data_at(:namespace, :complianceFrameworks, :nodes)).to be_empty
        end
      end
    end

    context 'when querying multiple namespaces' do
      let(:group) { create(:group, organization: namespace.organization) }
      let(:sox_framework) { create(:compliance_framework, namespace: group, name: 'SOX') }
      let(:multiple_namespace_query) do
        <<~QUERY
          query {
            a: namespace(fullPath: "#{namespace.full_path}") {
              complianceFrameworks { nodes { id name } }
            }
            b: namespace(fullPath: "#{group.full_path}") {
              complianceFrameworks { nodes { id name } }
            }
            c: namespace(fullPath: "#{group.full_path}") {
              complianceFrameworks(id: "#{sox_framework.to_global_id}") { nodes { id name } }
            }
          }
        QUERY
      end

      before do
        create(:compliance_framework, namespace: group, name: 'GDPR')
        group.add_owner(current_user)
      end

      it 'avoids N+1 queries' do
        post_graphql(query, current_user: current_user)
        post_graphql(multiple_namespace_query, current_user: current_user)

        control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

        expect do
          post_graphql(multiple_namespace_query, current_user: current_user)
        end.not_to exceed_query_limit(control).with_threshold(2)
      end

      it 'responds with the expected list of compliance frameworks' do
        post_graphql(multiple_namespace_query, current_user: current_user)

        expect(graphql_data_at(:a, :complianceFrameworks, :nodes, :name)).to contain_exactly('Test1', 'Test2')
        expect(graphql_data_at(:b, :complianceFrameworks, :nodes, :name)).to contain_exactly('GDPR', 'SOX')
        expect(graphql_data_at(:c, :complianceFrameworks, :nodes, :name)).to contain_exactly('SOX')
      end

      context 'when querying multiple framework IDs' do
        before do
          create(:compliance_framework, namespace: namespace, name: 'Test 3')
        end

        let(:multiple_namespace_query) do
          <<~QUERY
            query($complianceFrameworkIds: [ComplianceManagementFrameworkID!]) {
              a: namespace(fullPath: "#{namespace.full_path}") {
                complianceFrameworks(ids: $complianceFrameworkIds) { nodes { id name } }
              }
              b: namespace(fullPath: "#{group.full_path}") {
                complianceFrameworks { nodes { id name } }
              }
              c: namespace(fullPath: "#{group.full_path}") {
                complianceFrameworks(ids: ["#{sox_framework.to_global_id}"]) { nodes { id name } }
              }
            }
          QUERY
        end

        let(:query_variables) do
          { complianceFrameworkIds: [compliance_framework_1.to_global_id, compliance_framework_2.to_global_id] }
        end

        it 'responds with the expected list of compliance frameworks' do
          post_graphql(multiple_namespace_query, current_user: current_user, variables: query_variables)

          expect(graphql_data_at(:a, :complianceFrameworks, :nodes, :name)).to contain_exactly('Test1', 'Test2')
          expect(graphql_data_at(:b, :complianceFrameworks, :nodes, :name)).to contain_exactly('GDPR', 'SOX')
          expect(graphql_data_at(:c, :complianceFrameworks, :nodes, :name)).to contain_exactly('SOX')
        end
      end
    end

    context 'when searching frameworks by name' do
      let_it_be(:compliance_framework_3) { create(:compliance_framework, namespace: namespace, name: 'RandomTest3') }
      let_it_be(:framework_of_other_group) do
        create(:compliance_framework, namespace: create(:group), name: 'RandomTest4')
      end

      before do
        create(:compliance_framework, namespace: namespace, name: 'RandomName5')
      end

      context 'when frameworks exist with name similar to the search query' do
        let(:query) do
          graphql_query_for(
            :namespace, { full_path: namespace.full_path },
            query_nodes(:compliance_frameworks, nil, args: { search: "Test" })
          )
        end

        it 'returns the compliance frameworks' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(:namespace, :complianceFrameworks, :nodes, :name))
            .to contain_exactly('Test1', 'Test2', 'RandomTest3')
        end
      end

      context 'when no framework exist with the name as per search term' do
        let(:query) do
          graphql_query_for(
            :namespace, { full_path: namespace.full_path },
            query_nodes(:compliance_frameworks, nil, args: { search: "NonExistentName" })
          )
        end

        it 'does not returns any compliance framework' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(:namespace, :complianceFrameworks, :nodes)).to be_empty
        end
      end

      context 'when the search string is empty' do
        let(:query) do
          graphql_query_for(
            :namespace, { full_path: namespace.full_path },
            query_nodes(:compliance_frameworks, nil, args: { search: "" })
          )
        end

        it 'returns the compliance frameworks' do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(:namespace, :complianceFrameworks, :nodes, :name))
            .to contain_exactly('Test1', 'Test2', 'RandomTest3', 'RandomName5')
        end
      end
    end
  end

  context 'when authenticated as a different user' do
    let_it_be(:current_user) { create(:user) }

    context('when querying a top-level namespace') do
      it "does not return the namespaces compliance frameworks" do
        post_graphql(query, current_user: current_user)

        expect(graphql_data_at(*path)).to be_nil
      end
    end

    context('when querying a subgroup') do
      let(:query) do
        graphql_query_for(
          :namespace, { full_path: subgroup.full_path }, query_nodes(:compliance_frameworks)
        )
      end

      context('when user is an owner') do
        before_all do
          subgroup.add_owner(current_user)
        end

        it "returns frameworks of top-level namespace" do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(*path)).to contain_exactly(
            a_graphql_entity_for(compliance_framework_1),
            a_graphql_entity_for(compliance_framework_2)
          )
        end
      end

      context('when user is not an owner') do
        it "does not return the namespaces compliance frameworks" do
          post_graphql(query, current_user: current_user)

          expect(graphql_data_at(*path)).to be_nil
        end
      end
    end
  end

  context 'when not authenticated' do
    it "does not return the namespace's compliance frameworks" do
      post_graphql(query)

      expect(graphql_data_at(*path)).to be_nil
    end
  end
end
