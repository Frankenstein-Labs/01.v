# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::BillableMember, feature_category: :seat_cost_management do
  # rubocop:disable Rails/Date -- TODO: needs to be updated
  let_it_be(:last_activity_on) { Date.today - 1.day }
  # rubocop:enable Rails/Date
  let_it_be(:current_sign_in_at) { DateTime.now - 2.days }
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:current_user_member) { create(:group_member, :owner, user: current_user, group: group) }
  let_it_be_with_reload(:user) do
    create(:user, last_activity_on: last_activity_on, current_sign_in_at: current_sign_in_at)
  end

  let_it_be(:user_member) { create(:group_member, :owner, user: user, group: group) }

  let(:options) do
    {
      group: group,
      current_user: current_user,
      group_member_user_ids: [],
      project_member_user_ids: [],
      shared_group_user_ids: [],
      shared_project_user_ids: [],
      owners: group.member_owners_excluding_project_bots_and_service_accounts
    }
  end

  subject(:entity_representation) { described_class.new(user, options).as_json }

  context 'when current_user option is nil' do
    let(:current_user) { nil }

    it 'exposes basic attributes' do
      expect(entity_representation).to be_kind_of(Hash)
    end
  end

  it 'returns the last_activity_on attribute' do
    expect(entity_representation[:last_activity_on]).to eq user.last_activity_on
  end

  it 'exposes the last_login_at field' do
    expect(entity_representation[:last_login_at]).to eq user.current_sign_in_at
  end

  it 'exposes the created_at field' do
    expect(entity_representation[:created_at]).to eq(user.created_at)
  end

  it 'exposes the is_last_owner field' do
    expect(entity_representation[:is_last_owner]).to eq(group.last_owner?(user))
  end

  describe 'email field' do
    shared_examples "returns the user's public_email" do
      it "returns the user's public_email" do
        aggregate_failures do
          expect(entity_representation.keys).to include(:email)
          expect(entity_representation[:email]).to eq user.public_email
          expect(entity_representation[:email]).not_to eq user.email
        end
      end
    end

    shared_examples "returns the user's primary email" do
      it "returns the user's primary email" do
        aggregate_failures do
          expect(entity_representation.keys).to include(:email)
          expect(entity_representation[:email]).to eq user.email
          expect(entity_representation[:email]).not_to eq user.public_email
        end
      end
    end

    context 'when the user has no public_email assigned' do
      before do
        user.update!(public_email: nil)
      end

      include_examples "returns the user's public_email"
    end

    context 'when the user has a public_email assigned' do
      let_it_be(:user_public_email) do
        create(:email, :confirmed, user: user, email: 'user-public-email@example.com')
      end

      before do
        user.update!(public_email: user_public_email.email)
      end

      include_examples "returns the user's public_email"
    end

    context 'when the current_user is an admin' do
      let_it_be(:current_user) { create(:user, :admin) }

      context 'when admin mode enabled', :enable_admin_mode do
        include_examples "returns the user's primary email"
      end

      context 'when admin mode disabled' do
        include_examples "returns the user's public_email"
      end
    end

    context 'on SaaS', :saas do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:another_group) { create(:group_member, :owner, user: current_user).group }

      where(:domain_verification_availabe_for_group, :user_is_enterprise_user_of_the_group, :shared_examples) do
        false | false | "returns the user's public_email"
        false | true  | "returns the user's public_email"
        true  | false | "returns the user's public_email"
        true  | true  | "returns the user's primary email"
      end

      with_them do
        before do
          stub_licensed_features(domain_verification: domain_verification_availabe_for_group)

          user.user_detail.enterprise_group_id = user_is_enterprise_user_of_the_group ? group.id : another_group.id
        end

        include_examples params[:shared_examples]
      end
    end
  end

  context 'with different group membership types' do
    using RSpec::Parameterized::TableSyntax

    where(:user_ids, :membership_type, :removable) do
      :group_member_user_ids   | 'group_member'   | true
      :project_member_user_ids | 'project_member' | true
      :shared_group_user_ids   | 'group_invite'   | false
      :shared_project_user_ids | 'project_invite' | false
    end

    with_them do
      let(:options) { super().merge(user_ids => [user.id]) }

      it 'returns the expected membership_type value' do
        expect(entity_representation[:membership_type]).to eq membership_type
      end

      it 'returns the expected removable value' do
        expect(entity_representation[:removable]).to eq removable
      end
    end

    context 'with a missing membership type' do
      before do
        options.delete(:group_member_user_ids)
      end

      it 'does not raise an error' do
        expect(options[:group_member_user_ids]).to be_nil
        expect { entity_representation }.not_to raise_error
      end
    end
  end
end
