# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AwardEmoji, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  describe 'callbacks' do
    describe 'before_validation' do
      describe '#rewrite_epic_awardable_type' do
        let_it_be(:issue) { create(:issue) }
        let_it_be(:epic) { create(:epic) }

        context 'when creating an award emoji with Epic awardable_type' do
          it 'rewrites awardable_type from Epic to Issue' do
            award_emoji = build(:award_emoji, awardable_type: 'Epic', awardable_id: epic.id, user: user)

            expect { award_emoji.save! }.to change { award_emoji.awardable_type }.from('Epic').to('Issue')
              .and change { award_emoji.awardable_id }.from(epic.id).to(epic.issue_id)
          end
        end

        context 'when updating an existing award emoji' do
          let_it_be_with_reload(:award_emoji) { create(:award_emoji, awardable: issue, user: user) }

          it 'does not rewrite awardable_type on update' do
            award_emoji.awardable_type = 'Epic'
            award_emoji.awardable_id = epic.id

            award_emoji.save!

            expect(award_emoji.reload.awardable_type).to eq('Epic')
            expect(award_emoji.reload.awardable_id).to eq(epic.id)
          end
        end

        context 'when awardable_type is not Epic' do
          it 'does not modify awardable_type for Issue' do
            award_emoji = build(:award_emoji, awardable: issue, user: user)

            award_emoji.save!

            expect(award_emoji.reload.awardable_type).to eq('Issue')
            expect(award_emoji.reload.awardable_id).to eq(issue.id)
          end
        end
      end
    end
  end

  describe 'validations' do
    context 'custom emoji' do
      let_it_be(:emoji) { create(:custom_emoji, name: 'partyparrot', namespace: group) }

      before_all do
        group.add_maintainer(user)
      end

      it 'accepts custom emoji on epic' do
        epic = create(:epic, group: group)
        new_award = build(:award_emoji, user: user, awardable: epic, name: emoji.name)

        expect(new_award).to be_valid
      end

      it 'accepts custom emoji on subgroup epic' do
        subgroup = create(:group, parent: group)
        epic = create(:epic, group: subgroup)
        new_award = build(:award_emoji, user: user, awardable: epic, name: emoji.name)

        expect(new_award).to be_valid
      end
    end
  end

  describe '#ensure_sharding_key' do
    using RSpec::Parameterized::TableSyntax

    let(:epic) { create(:epic, group: group) }
    let(:group_id) { group.id }

    where(:awardable, :namespace_id, :organization_id) do
      ref(:epic) | ref(:group_id) | nil
    end

    with_them do
      it 'sets the correct sharding key' do
        award_emoji = build(:award_emoji, awardable: awardable)
        award_emoji.valid?

        expect(award_emoji).to be_valid
        expect(award_emoji.namespace_id).to eq(namespace_id)
        expect(award_emoji.organization_id).to eq(organization_id)
      end
    end
  end
end
