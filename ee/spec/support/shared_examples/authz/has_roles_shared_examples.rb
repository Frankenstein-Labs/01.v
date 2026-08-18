# frozen_string_literal: true

RSpec.shared_examples 'a resource that has custom roles' do |resource_type|
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:admin, freeze: false) { create(:admin) }
  let_it_be(:resource, freeze: false) { create(resource_type) } # rubocop: disable Rails/SaveBang -- there is no create! method in FactoryBot

  describe '#custom_role_abilities_too_high?' do
    subject(:custom_role_abilities_too_high?) do
      resource.custom_role_abilities_too_high?(current_user: user, target_member_role_id: member_role_id)
    end

    let_it_be(:member_role_current_user, freeze: false) do
      create(:member_role, :maintainer, admin_merge_request: true, namespace: resource.root_ancestor)
    end

    let_it_be(:member_role_less_abilities, freeze: false) do
      create(:member_role, :guest, admin_merge_request: true, namespace: resource.root_ancestor)
    end

    let_it_be(:member_role_more_abilities, freeze: false) do
      create(:member_role, :guest, admin_merge_request: true, admin_push_rules: true, remove_project: true,
        namespace: resource.root_ancestor)
    end

    let(:member_role_id) { nil }

    context 'when current user is not a member' do
      let(:member_role_id) { member_role_more_abilities.id }

      it 'returns true' do
        expect(custom_role_abilities_too_high?).to be(true)
      end
    end

    context 'when user is a member' do
      let_it_be_with_reload(:current_member) { resource.add_maintainer(user) }

      before do
        current_member.update!(member_role: member_role_current_user)
        stub_licensed_features(custom_roles: true)
      end

      context 'with the same custom role as current user has' do
        let(:member_role_id) { member_role_current_user.id }

        it 'returns false' do
          expect(custom_role_abilities_too_high?).to be(false)
        end
      end

      context "with custom role abilities included in the current user's base access" do
        let(:member_role_included_abilities) do
          create(:member_role, :guest, read_vulnerability: true, admin_push_rules: true,
            namespace: resource.root_ancestor)
        end

        let(:member_role_id) { member_role_included_abilities.id }

        it 'returns false' do
          expect(custom_role_abilities_too_high?).to be(false)
        end

        context "when current user doesn't have a custom role" do
          let(:member_role_current_user) { nil }

          it 'returns false' do
            expect(custom_role_abilities_too_high?).to be(false)
          end
        end
      end

      context 'with the custom role having less abilities than current user has' do
        let(:member_role_id) { member_role_less_abilities.id }

        it 'returns false' do
          expect(custom_role_abilities_too_high?).to be(false)
        end
      end

      context 'with the custom role having more abilities than current user has' do
        let(:member_role_id) { member_role_more_abilities.id }

        it 'returns true' do
          expect(custom_role_abilities_too_high?).to be(true)
        end

        context 'when current user is an admin', :enable_admin_mode do
          let(:user) { admin }

          it 'returns false' do
            expect(custom_role_abilities_too_high?).to be(false)
          end
        end
      end
    end
  end
end
