# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::EnterpriseUsersFinder, feature_category: :user_management do
  describe '#execute' do
    let_it_be(:enterprise_group) { create(:group) }

    let_it_be(:subgroup) { create(:group, parent: enterprise_group) }

    let_it_be(:developer_of_enterprise_group) { create(:user, developer_of: enterprise_group) }
    let_it_be(:maintainer_of_enterprise_group) { create(:user, maintainer_of: enterprise_group) }
    let_it_be(:owner_of_enterprise_group) { create(:user, owner_of: enterprise_group) }

    let_it_be(:non_enterprise_user) { create(:user) }
    let_it_be(:enterprise_user_of_another_group) { create(:enterprise_user) }

    let_it_be(:enterprise_user_of_the_group) do
      create(:enterprise_user, enterprise_group: enterprise_group)
    end

    let_it_be(:blocked_enterprise_user_of_the_group) do
      create(:enterprise_user, :blocked, enterprise_group: enterprise_group)
    end

    let_it_be(:enterprise_user_and_member_of_the_group) do
      create(:enterprise_user, enterprise_group: enterprise_group, developer_of: enterprise_group)
    end

    let(:current_user) { owner_of_enterprise_group }

    let(:params) { { enterprise_group: enterprise_group } }

    subject(:finder) { described_class.new(current_user, params).execute }

    describe '#execute' do
      context 'when enterprise_group parameter is not passed' do
        let(:params) { {} }

        it 'raises error that enterprise group is required' do
          expect { finder }.to raise_error(ArgumentError, 'Enterprise group is required for EnterpriseUsersFinder')
        end
      end

      context 'when enterprise_group parameter is not top-level group' do
        let(:params) { { enterprise_group: subgroup } }

        it 'raises error that enterprise group must be a top-level group' do
          expect { finder }.to raise_error(ArgumentError, 'Enterprise group must be a top-level group')
        end
      end

      context 'when current_user is not owner of the group' do
        let(:current_user) { maintainer_of_enterprise_group }

        it 'raises Gitlab::Access::AccessDeniedError' do
          expect { finder }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end

      it 'returns enterprise users of the group in descending order by id' do
        users = finder

        expect(users).to eq(
          [
            enterprise_user_of_the_group,
            blocked_enterprise_user_of_the_group,
            enterprise_user_and_member_of_the_group
          ].sort_by(&:id).reverse
        )
      end

      context 'for search parameter' do
        context 'for search by name' do
          let(:params) { { enterprise_group: enterprise_group, search: enterprise_user_of_the_group.name } }

          it 'returns enterprise users of the group according to the search parameter' do
            users = finder

            expect(users).to eq(
              [
                enterprise_user_of_the_group
              ]
            )
          end
        end

        context 'for search by username' do
          let(:params) { { enterprise_group: enterprise_group, search: blocked_enterprise_user_of_the_group.username } }

          it 'returns enterprise users of the group according to the search parameter' do
            users = finder

            expect(users).to eq(
              [
                blocked_enterprise_user_of_the_group
              ]
            )
          end
        end

        context 'for search by public email' do
          let_it_be(:enterprise_user_of_the_group_with_public_email) do
            create(:enterprise_user, :public_email, enterprise_group: enterprise_group)
          end

          let(:params) do
            { enterprise_group: enterprise_group, search: enterprise_user_of_the_group_with_public_email.public_email }
          end

          it 'returns enterprise users of the group according to the search parameter', :aggregate_failures do
            expect(enterprise_user_of_the_group_with_public_email.public_email).to be_present

            users = finder

            expect(users).to eq(
              [
                enterprise_user_of_the_group_with_public_email
              ]
            )
          end
        end

        context 'for search by private email' do
          let_it_be(:enterprise_user_of_the_group_without_public_email) do
            create(:enterprise_user, enterprise_group: enterprise_group)
          end

          let(:params) do
            { enterprise_group: enterprise_group, search: enterprise_user_of_the_group_without_public_email.email }
          end

          it 'returns enterprise users of the group according to the search parameter', :aggregate_failures do
            expect(enterprise_user_of_the_group_without_public_email.public_email).not_to be_present

            users = finder

            expect(users).to eq(
              [
                enterprise_user_of_the_group_without_public_email
              ]
            )
          end
        end
      end
    end
  end
end
