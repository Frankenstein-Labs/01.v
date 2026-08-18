# frozen_string_literal: true

RSpec.shared_examples 'promotion management for members bulk update' do
  let(:fields) do
    <<-FIELDS
      errors
      queuedMemberApprovals {
        nodes {
          status
          newAccessLevel {
            integerValue
            humanAccess
          }
          oldAccessLevel {
            integerValue
            humanAccess
          }
        }
        count
      }
      #{response_member_field} {
        accessLevel {
          integerValue
          stringValue
          humanAccess
        }
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(mutation_name, input_params, fields) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let(:promoted_access_level) { Gitlab::Access::DEVELOPER }
  let(:input_params) do
    {
      source_id_key => source.to_global_id.to_s,
      'user_ids' => users.map(&:to_global_id).map(&:to_s),
      'access_level' => 'DEVELOPER'
    }
  end

  let_it_be(:users, freeze: false) { create_list(:user, 2) }
  let_it_be(:license, freeze: false) { create(:license, plan: License::ULTIMATE_PLAN) }

  before do
    users.each do |user|
      source.add_guest(user)
    end

    source.add_owner(current_user)
    stub_application_setting(enable_member_promotion_management: true)
    allow(License).to receive(:current).and_return(license)
  end

  RSpec.shared_examples 'updates all members' do
    it do
      post_graphql_mutation(mutation, current_user: current_user)
      new_access_levels = mutation_response[response_member_field].map do |member|
        member['accessLevel']['integerValue']
      end

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(new_access_levels).to all(be promoted_access_level)
    end
  end

  context 'when member_promotion_management is disabled' do
    before do
      stub_application_setting(enable_member_promotion_management: false)
    end

    it_behaves_like 'updates all members'
  end

  context 'when on SaaS', :saas do
    it_behaves_like 'updates all members'
  end

  context 'when on SM' do
    it 'queues non billable users promotions to billable roles' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['queuedMemberApprovals']["count"]).to eq(2)

      queued_members = mutation_response['queuedMemberApprovals']['nodes']
      queued_new_access_levels = queued_members.map do |member_approval|
        member_approval['newAccessLevel']['integerValue']
      end

      queued_old_access_levels = queued_members.map do |member_approval|
        member_approval['oldAccessLevel']['integerValue']
      end

      statuses = queued_members.pluck('status')
      expect(statuses).to all(eq('pending'))
      expect(queued_new_access_levels).to all(be promoted_access_level)
      expect(queued_old_access_levels).to all(be Gitlab::Access::GUEST)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response[response_member_field]).to be_empty
    end

    context 'when users are already billable' do
      let(:promoted_access_level) { Gitlab::Access::MAINTAINER }

      before do
        input_params['access_level'] = 'MAINTAINER'

        users.each do |user|
          source.add_developer(user)
        end
      end

      it_behaves_like 'updates all members'
    end
  end
end
