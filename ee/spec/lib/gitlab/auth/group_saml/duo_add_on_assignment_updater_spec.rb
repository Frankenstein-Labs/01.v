# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::DuoAddOnAssignmentUpdater, feature_category: :user_management do
  describe '#execute', :sidekiq_inline do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let(:auth_hash) { build_auth_hash(saml_groups) }
    let(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_pro, expires_on: 1.week.from_now, namespace: group)
    end

    subject(:execute) { described_class.new(user, group, auth_hash).execute }

    before_all do
      group.add_developer(user)
    end

    before do
      allow(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async)
      stub_saas_features(gitlab_duo_saas_only: true)
    end

    shared_examples 'does not modify assignments' do
      it 'does not modify assignments' do
        expect { execute }
          .not_to change { user.assigned_add_ons.count }
      end
    end

    shared_examples 'creates assignment' do
      it 'schedules assignment creation and adds the seat' do
        expect { execute }
          .to change { user.assigned_add_ons.for_active_add_on_purchase_ids(add_on_purchase.id).count }
                .from(0).to(1)
      end
    end

    shared_examples 'removes assignment' do
      it 'schedules assignment destruction and removes the seat' do
        expect { execute }
          .to change { user.assigned_add_ons.for_active_add_on_purchase_ids(add_on_purchase.id).count }
                .from(1).to(0)
      end
    end

    context 'for main functionality' do
      where(:duo_group_link, :active_add_on, :saml_groups, :existing_assignment, :shared_examples) do
        # Test early returns
        false | true  | ['Duo']        | false | 'does not modify assignments'
        false | true  | ['Duo']        | true  | 'does not modify assignments'
        true  | false | ['Duo']        | false | 'does not modify assignments'

        # Test main functionality
        true  | true  | ['Duo']        | false | 'creates assignment'
        true  | true  | ['Duo']        | true  | 'does not modify assignments'
        true  | true  | ['Other']      | true  | 'removes assignment'
        true  | true  | ['Other']      | false | 'does not modify assignments'
        true  | true  | []             | true  | 'removes assignment'
        true  | true  | []             | false | 'does not modify assignments'
        true  | true  | nil            | true  | 'removes assignment'
        true  | true  | %w[Duo Dev]    | false | 'creates assignment'
      end

      with_them do
        before do
          create(:saml_group_link, group: group, saml_group_name: 'Duo', assign_duo_seats: true) if duo_group_link

          add_on_purchase if active_add_on

          if existing_assignment && active_add_on
            create(:gitlab_subscription_user_add_on_assignment,
              user: user,
              add_on_purchase: add_on_purchase
            )
          end
        end

        include_examples params[:shared_examples]
      end
    end

    context 'with multiple Duo group links' do
      let(:saml_groups) { ['Engineering'] }

      before do
        add_on_purchase

        # Create multiple Duo group links
        create(:saml_group_link, group: group, saml_group_name: 'Duo', assign_duo_seats: true)
        create(:saml_group_link, group: group, saml_group_name: 'Engineering', assign_duo_seats: true)
        create(:saml_group_link, group: group, saml_group_name: 'Sales', assign_duo_seats: false) # Non-Duo link
      end

      it 'creates assignment when user is in any Duo group' do
        expect { execute }
          .to change { user.assigned_add_ons.for_active_add_on_purchase_ids(add_on_purchase.id).count }
                .from(0).to(1)
      end
    end

    context 'with inactive add-on purchase' do
      let(:saml_groups) { ['Duo'] }
      let(:active_add_on) { false }

      before do
        create(:saml_group_link, group: group, saml_group_name: 'Duo', assign_duo_seats: true)

        create(
          :gitlab_subscription_add_on_purchase,
          :duo_pro,
          expires_on: 1.day.ago,
          namespace: group
        )
      end

      include_examples 'does not modify assignments'
    end

    private

    def build_auth_hash(groups)
      ::Gitlab::Auth::GroupSaml::AuthHash.new(
        OmniAuth::AuthHash.new(
          extra: {
            raw_info: OneLogin::RubySaml::Attributes.new({ 'groups' => groups })
          }
        )
      )
    end
  end
end
