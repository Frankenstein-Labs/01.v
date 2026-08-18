# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::TrackedRefsFinder, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:main_branch) { create(:security_project_tracked_context, :tracked, :default, project: project) }
  let_it_be(:tag_ref) do
    create(:security_project_tracked_context, :tracked, :tag, project: project, context_name: 'v1.0')
  end

  let_it_be(:untracked_ref) do
    create(:security_project_tracked_context, :untracked, project: project, context_name: 'untracked-branch')
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe '#execute' do
    context 'when user has developer access' do
      before_all { project.add_developer(user) }

      context 'with no state filter' do
        subject(:finder) { described_class.new(project, user) }

        it 'returns all refs for the project' do
          expect(finder.execute).to contain_exactly(main_branch, tag_ref, untracked_ref)
        end
      end

      context 'with state filter' do
        it 'returns only tracked refs when state is "tracked"' do
          finder = described_class.new(project, user, { state: 'TRACKED' })

          expect(finder.execute).to contain_exactly(main_branch, tag_ref)
        end

        it 'returns only untracked refs when state is "untracked"' do
          finder = described_class.new(project, user, { state: 'UNTRACKED' })

          expect(finder.execute).to contain_exactly(untracked_ref)
        end

        it 'returns all refs when state is invalid' do
          finder = described_class.new(project, user, { state: 'INVALID' })

          expect(finder.execute).to contain_exactly(main_branch, tag_ref, untracked_ref)
        end
      end
    end

    context 'when user lacks permission' do
      subject(:finder) { described_class.new(project, user) }

      it 'returns empty relation' do
        expect(finder.execute).to be_empty
      end
    end

    context 'when user is nil' do
      subject(:finder) { described_class.new(project, nil) }

      it 'returns empty relation' do
        expect(finder.execute).to be_empty
      end
    end
  end
end
