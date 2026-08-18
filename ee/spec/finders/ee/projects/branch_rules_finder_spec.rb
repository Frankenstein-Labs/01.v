# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::BranchRulesFinder, feature_category: :source_code_management, type: :model do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:all_branches_rule) { Projects::AllBranchesRule.new(project) }
  let_it_be(:all_protected_branches_rule) { Projects::AllProtectedBranchesRule.new(project) }
  let_it_be(:custom_rules) { [all_branches_rule, all_protected_branches_rule] }

  let(:protected_branches) { project.protected_branches.sorted_by_name }
  let(:finder) do
    described_class.new(project, custom_rules: custom_rules, protected_branches: protected_branches)
  end

  describe '#execute' do
    subject(:page) { finder.execute(cursor: cursor, limit: limit) }

    let(:cursor) { nil }
    let(:limit) { 20 }

    context 'with all protected branches rule' do
      let!(:protected_branch_a) { create(:protected_branch, project: project, name: 'abranch') }
      let!(:protected_branch_b) { create(:protected_branch, project: project, name: 'bbranch') }

      it 'includes all custom rules in order' do
        expect(page.rules.size).to eq(4)
        expect(page.rules[0]).to eq(all_branches_rule)
        expect(page.rules[1]).to eq(all_protected_branches_rule)
        expect(page.rules[2].protected_branch).to eq(protected_branch_a)
        expect(page.rules[3].protected_branch).to eq(protected_branch_b)
      end

      context 'when paginating after all_branches rule' do
        let(:cursor) { encode_cursor('all_branches') }
        let(:limit) { 2 }

        it 'returns all_protected_branches rule and protected branches' do
          expect(page.rules.size).to eq(2)
          expect(page.rules[0]).to eq(all_protected_branches_rule)
          expect(page.rules[1].protected_branch).to eq(protected_branch_a)
          expect(page.has_next_page).to be true
        end
      end

      context 'when paginating after all_protected_branches rule' do
        let(:cursor) { encode_cursor('all_protected_branches') }
        let(:limit) { 2 }

        it 'returns protected branches' do
          expect(page.rules.size).to eq(2)
          expect(page.rules[0].protected_branch).to eq(protected_branch_a)
          expect(page.rules[1].protected_branch).to eq(protected_branch_b)
          expect(page.has_next_page).to be false
        end
      end
    end

    context 'when protected branch name matches custom rule identifier' do
      let!(:branch_aaa) { create(:protected_branch, project: project, name: 'aaa') }
      let!(:branch_all_protected) { create(:protected_branch, project: project, name: 'all_protected_branches') }
      let!(:branch_zzz) { create(:protected_branch, project: project, name: 'zzz') }
      let(:cursor) { encode_cursor('all_protected_branches', branch_all_protected.id) }

      it 'paginates correctly when protected branch has same name as custom rule' do
        expect(page.rules.map(&:name)).to include('zzz')
        expect(page.rules.map(&:name)).not_to include('aaa', 'all_protected_branches')
      end
    end
  end

  def encode_cursor(name, id = nil)
    return unless name

    cursor = { name: name, id: id }.to_json
    Base64.strict_encode64(cursor)
  end
end
