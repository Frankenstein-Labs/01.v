# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::Saml::DuoAddOnAssignmentUpdater, feature_category: :user_management do
  describe '#execute', :sidekiq_inline do
    include LoginHelpers
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let(:auth_hash) { build_auth_hash(saml_groups) }
    let(:group) { create(:group) }
    let(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_pro, expires_on: 1.week.from_now, namespace: nil)
    end

    subject(:execute) { described_class.new(user, auth_hash).execute }

    before do
      allow(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async)
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
      where(:saml_duo_config, :active_add_on, :saml_groups, :existing_assignment, :shared_examples) do
        # Test early returns
        {}                                    | true  | ['Duo']        | false | 'does not modify assignments'
        { duo_add_on_groups: ['Duo'] }        | true  | ['Duo']        | true  | 'does not modify assignments'
        { duo_add_on_groups: ['Duo'] }        | false | ['Duo']        | false | 'does not modify assignments'

        # Test main functionality
        { duo_add_on_groups: ['Duo'] }        | true  | ['Duo']        | false | 'creates assignment'
        { duo_add_on_groups: ['Duo'] }        | true  | ['Other']      | true  | 'removes assignment'
        { duo_add_on_groups: ['Duo'] }        | true  | ['Other']      | false | 'does not modify assignments'
        { duo_add_on_groups: ['Duo'] }        | true  | []             | true  | 'removes assignment'
        { duo_add_on_groups: ['Duo'] }        | true  | []             | false | 'does not modify assignments'
        { duo_add_on_groups: ['Duo'] }        | true  | nil            | true  | 'removes assignment'
        { duo_add_on_groups: ['Duo'] }        | true  | %w[Duo Dev]    | false | 'creates assignment'
        { duo_add_on_groups: %w[Duo Other] }  | true  | ['Other']      | false | 'creates assignment'
      end

      with_them do
        before do
          saml_config = { name: 'saml', groups_attribute: 'Groups', args: {} }
          saml_config.merge!(saml_duo_config)
          stub_omniauth_config(providers: [saml_config])

          add_on_purchase if active_add_on

          if existing_assignment && active_add_on
            create(
              :gitlab_subscription_user_add_on_assignment,
              user: user,
              add_on_purchase: add_on_purchase
            )
          end
        end

        include_examples params[:shared_examples]
      end
    end

    context 'with inactive add-on purchase' do
      let(:saml_groups) { ['Duo'] }

      before do
        stub_omniauth_config(
          providers: [{ name: 'saml', groups_attribute: 'Groups', duo_add_on_groups: ['Duo'], args: {} }]
        )

        create(
          :gitlab_subscription_add_on_purchase,
          :duo_pro,
          expires_on: 1.day.ago,
          namespace: nil
        )
      end

      include_examples 'does not modify assignments'
    end

    def build_auth_hash(groups)
      ::Gitlab::Auth::Saml::AuthHash.new(
        OmniAuth::AuthHash.new(
          provider: 'saml',
          extra: {
            raw_info: OneLogin::RubySaml::Attributes.new({ 'Groups' => groups })
          }
        )
      )
    end
  end
end
