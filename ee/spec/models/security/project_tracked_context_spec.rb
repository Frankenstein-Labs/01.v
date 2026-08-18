# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContext, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:sbom_occurrence_refs) }
    it { is_expected.to have_many(:vulnerability_reads) }
  end

  describe 'validations' do
    subject(:new_ref) { build(:security_project_tracked_context, project: project) }

    it { is_expected.to validate_presence_of(:context_name) }
    it { is_expected.to validate_presence_of(:context_type) }
    it { is_expected.to validate_length_of(:context_name).is_at_most(1024) }
    it { is_expected.to validate_uniqueness_of(:context_name).scoped_to([:project_id, :context_type]) }

    it 'is invalid when trying to make a tag ref default' do
      new_ref.context_type = :tag
      new_ref.is_default = true

      expect(new_ref).not_to be_valid
      expect(new_ref.errors[:base]).to include('only branch refs can be default')
    end

    describe 'tracked_refs_limit' do
      before do
        stub_feature_flags(vac_increased_limit: false)
      end

      it 'allows up to MAX_TRACKED_REFS_PER_PROJECT tracked refs' do
        create_list(:security_project_tracked_context, described_class::MAX_TRACKED_REFS_PER_PROJECT - 1, :tracked,
          project: project)

        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref).to be_valid
      end

      it 'prevents exceeding MAX_TRACKED_REFS_PER_PROJECT tracked refs' do
        create_list(:security_project_tracked_context, described_class::MAX_TRACKED_REFS_PER_PROJECT, :tracked,
          project: project)

        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref).not_to be_valid
        expect(ref.errors[:base]).to include(
          "cannot exceed #{described_class::MAX_TRACKED_REFS_PER_PROJECT} tracked refs per project"
        )
      end

      it 'allows unlimited untracked refs' do
        stub_const("#{described_class}::MAX_TRACKED_REFS_PER_PROJECT", 1)
        create_list(:security_project_tracked_context, 2, project: project)

        ref = build(:security_project_tracked_context, project: project)
        expect(ref).to be_valid
      end

      context 'when vac_increased_limit feature flag is enabled' do
        before do
          stub_feature_flags(vac_increased_limit: project)
          stub_const("#{described_class}::MAX_TRACKED_REFS_INCREASED", 3)
        end

        it 'allows up to MAX_TRACKED_REFS_INCREASED tracked refs' do
          create_list(:security_project_tracked_context, 2, :tracked, project: project)

          ref = build(:security_project_tracked_context, :tracked, project: project)
          expect(ref).to be_valid
        end

        it 'uses increased limit in error message when exceeded' do
          create_list(:security_project_tracked_context, 3, :tracked, project: project)

          ref = build(:security_project_tracked_context, :tracked, project: project)
          expect(ref).not_to be_valid
          expect(ref.errors[:base]).to include(
            "cannot exceed #{described_class::MAX_TRACKED_REFS_INCREASED} tracked refs per project"
          )
        end
      end
    end

    describe 'default_ref_cannot_be_untracked' do
      # This is only true until we build the long term quota system
      it 'prevents default refs from being untracked' do
        ref = build(:security_project_tracked_context, :default, :untracked, project: project)
        expect(ref).not_to be_valid
        expect(ref.errors[:base]).to include('default ref must be tracked')
      end

      it 'allows default refs to be tracked' do
        ref = build(:security_project_tracked_context, :default, project: project)
        expect(ref).to be_valid
      end

      it 'allows non-default refs to be untracked' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :set_traversal_ids' do
      it 'sets traversal_ids from project namespace on create' do
        context = create(:security_project_tracked_context, project: project)

        expect(context.traversal_ids).to eq(project.namespace.traversal_ids)
      end

      it 'does not override traversal_ids if already set' do
        custom_ids = [1, 2, 3]
        context = create(:security_project_tracked_context, project: project, traversal_ids: custom_ids)

        expect(context.traversal_ids).to eq(custom_ids)
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:context_type).with_values(branch: 1, tag: 2) }
  end

  describe 'state machine events' do
    let_it_be_with_reload(:tracked_ref) { create(:security_project_tracked_context, :tracked, project: project) }
    let_it_be_with_reload(:untracked_ref) { create(:security_project_tracked_context, project: project) }

    describe '#archive!' do
      it 'transitions from untracked to archiving' do
        expect(untracked_ref.archive!).to be_truthy
        expect(untracked_ref.reload.state_name).to eq(:archiving)
      end

      it 'transitions from tracked to archiving' do
        expect(tracked_ref.archive!).to be_truthy
        expect(tracked_ref.reload.state_name).to eq(:archiving)
      end

      it 'returns false when called on archiving state' do
        archiving_ref = create(:security_project_tracked_context, :archiving, project: project)
        expect { archiving_ref.archive! }.to raise_error(StateMachines::InvalidTransition)
      end

      it 'returns false when called on deleting state' do
        deleting_ref = create(:security_project_tracked_context, :deleting, project: project)
        expect { deleting_ref.archive! }.to raise_error(StateMachines::InvalidTransition)
      end
    end

    describe '#remove!' do
      it 'transitions from untracked to deleting' do
        expect(untracked_ref.remove!).to be_truthy
        expect(untracked_ref.reload.state_name).to eq(:deleting)
      end

      it 'transitions from tracked to deleting' do
        tracked_ref_for_remove = create(:security_project_tracked_context, :tracked, project: project)
        expect(tracked_ref_for_remove.remove!).to be_truthy
        expect(tracked_ref_for_remove.reload.state_name).to eq(:deleting)
      end

      it 'transitions from archiving to deleting' do
        archiving_ref = create(:security_project_tracked_context, :archiving, project: project)
        expect(archiving_ref.remove!).to be_truthy
        expect(archiving_ref.reload.state_name).to eq(:deleting)
      end

      it 'allows deleting from deleting state' do
        deleting_ref = create(:security_project_tracked_context, :deleting, project: project)
        expect(deleting_ref.remove!).to be_truthy
        expect(deleting_ref.reload.state_name).to eq(:deleting)
      end
    end
  end

  describe 'state transition validations' do
    describe 'archive event' do
      it 'allows transition from untracked to archiving' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref.can_archive?).to be_truthy
      end

      it 'allows transition from tracked to archiving' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.can_archive?).to be_truthy
      end

      it 'does not allow transition from archiving to archiving' do
        ref = build(:security_project_tracked_context, :archiving, project: project)
        expect(ref.can_archive?).to be_falsey
      end

      it 'does not allow transition from deleting to archiving' do
        ref = build(:security_project_tracked_context, :deleting, project: project)
        expect(ref.can_archive?).to be_falsey
      end
    end

    describe 'remove event' do
      it 'allows transition from untracked to deleting' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref.can_remove?).to be_truthy
      end

      it 'allows transition from tracked to deleting' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.can_remove?).to be_truthy
      end

      it 'allows transition from archiving to deleting' do
        ref = build(:security_project_tracked_context, :archiving, project: project)
        expect(ref.can_remove?).to be_truthy
      end

      it 'allows transition from deleting to deleting' do
        ref = build(:security_project_tracked_context, :deleting, project: project)
        expect(ref.can_remove?).to be_truthy
      end
    end
  end

  describe 'state predicate methods' do
    describe '#untracked?' do
      it 'returns true when state is untracked' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref.untracked?).to be_truthy
      end

      it 'returns false when state is not untracked' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.untracked?).to be_falsey
      end
    end

    describe '#tracked?' do
      it 'returns true when state is tracked' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.tracked?).to be_truthy
      end

      it 'returns false when state is not tracked' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref.tracked?).to be_falsey
      end
    end

    describe '#archiving?' do
      it 'returns true when state is archiving' do
        ref = build(:security_project_tracked_context, :archiving, project: project)
        expect(ref.archiving?).to be_truthy
      end

      it 'returns false when state is not archiving' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.archiving?).to be_falsey
      end
    end

    describe '#deleting?' do
      it 'returns true when state is deleting' do
        ref = build(:security_project_tracked_context, :deleting, project: project)
        expect(ref.deleting?).to be_truthy
      end

      it 'returns false when state is not deleting' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.deleting?).to be_falsey
      end
    end
  end

  describe 'scopes' do
    let_it_be_with_reload(:tracked_ref) { create(:security_project_tracked_context, :tracked, project: project) }
    let_it_be_with_reload(:untracked_ref) { create(:security_project_tracked_context, project: project) }
    let_it_be(:default_ref) { create(:security_project_tracked_context, :default, project: project) }
    let_it_be(:other_project_ref) { create(:security_project_tracked_context, :tracked) }
    let_it_be(:archiving_ref) { create(:security_project_tracked_context, :archiving, project: project) }
    let_it_be(:deleting_ref) { create(:security_project_tracked_context, :deleting, project: project) }

    describe '.tracked' do
      it 'returns only tracked refs' do
        expect(described_class.tracked).to contain_exactly(tracked_ref, default_ref, other_project_ref)
      end
    end

    describe '.untracked' do
      it 'returns only untracked refs' do
        expect(described_class.untracked).to contain_exactly(untracked_ref)
      end
    end

    describe '.archiving' do
      it 'returns only archiving refs' do
        expect(described_class.archiving).to contain_exactly(archiving_ref)
      end
    end

    describe '.deleting' do
      it 'returns only deleting refs' do
        expect(described_class.deleting).to contain_exactly(deleting_ref)
      end
    end

    describe '.for_project' do
      it 'returns refs for the specified project' do
        expect(described_class.for_project(project.id)).to contain_exactly(tracked_ref, untracked_ref, default_ref,
          archiving_ref, deleting_ref)
      end
    end

    describe '.default_refs' do
      it 'returns only default refs' do
        expect(described_class.default_refs).to contain_exactly(default_ref)
      end
    end

    describe '.default_branch' do
      it 'returns only default branch refs' do
        expect(described_class.default_branch).to contain_exactly(default_ref)
      end

      it 'excludes tag refs' do
        stub_const("#{described_class}::MAX_TRACKED_REFS_PER_PROJECT", 3)

        tag_ref = create(:security_project_tracked_context, :tracked, :tag, context_name: default_ref.context_name,
          project: project)

        expect(described_class.default_branch).to contain_exactly(default_ref)
        expect(described_class.default_branch).not_to include(tag_ref)
      end

      it 'excludes non-default branch refs' do
        non_default_branch = create(:security_project_tracked_context, context_type: :branch, project: project)

        expect(described_class.default_branch).to contain_exactly(default_ref)
        expect(described_class.default_branch).not_to include(non_default_branch)
      end

      it 'returns empty when no default branch refs exist' do
        new_project = create(:project)

        expect(described_class.for_project(new_project.id).default_branch).to be_empty
      end
    end

    describe '.for_ref' do
      it 'returns refs with matching context_name that are branches or tags' do
        expect(described_class.for_ref(tracked_ref.context_name)).to contain_exactly(tracked_ref)
        expect(described_class.for_ref(default_ref.context_name)).to contain_exactly(default_ref)
      end

      it 'returns empty when no matching refs exist' do
        expect(described_class.for_ref('nonexistent-ref')).to be_empty
      end
    end
  end

  describe '.for_pipeline' do
    let_it_be(:branch_context) { create(:security_project_tracked_context, context_type: :branch, project: project) }
    let_it_be(:tag_context) { create(:security_project_tracked_context, context_type: :tag, project: project) }

    before_all do
      other_project = create(:project)
      create(:ci_pipeline, :tag, ref: tag_context.context_name, project: other_project)
      create(:ci_pipeline, ref: branch_context.context_name, project: other_project)
      create(:security_project_tracked_context,
        context_name: branch_context.context_name,
        context_type: :branch,
        project: other_project
      )
      create(:security_project_tracked_context,
        context_name: tag_context.context_name,
        context_type: :tag,
        project: other_project
      )
    end

    context 'with a branch pipeline' do
      let_it_be(:pipeline) { create(:ci_pipeline, ref: branch_context.context_name, project: project) }

      it 'returns refs matching the pipeline ref and type' do
        expect(described_class.for_pipeline(pipeline)).to contain_exactly(branch_context)
      end
    end

    context 'with a tag pipeline' do
      let_it_be(:pipeline) { create(:ci_pipeline, :tag, ref: tag_context.context_name, project: project) }

      it 'returns refs matching the pipeline ref and type' do
        expect(described_class.for_pipeline(pipeline)).to contain_exactly(tag_context)
      end
    end

    context 'when no matching ref exists' do
      let_it_be(:pipeline) { create(:ci_pipeline, ref: 'non-existent-branch', project: project) }

      it 'returns an empty relation' do
        expect(described_class.for_pipeline(pipeline)).to be_empty
      end
    end
  end

  describe '.tracked_pipeline?' do
    let_it_be(:tracked_branch_ref) do
      create(:security_project_tracked_context, :tracked, project: project, context_name: 'feature-branch')
    end

    let_it_be(:untracked_branch_ref) do
      create(:security_project_tracked_context, project: project, context_name: 'untracked-branch')
    end

    subject(:tracked_pipeline?) { described_class.tracked_pipeline?(pipeline) }

    context 'with a tracked pipeline' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: tracked_branch_ref.context_name) }

      it { is_expected.to be true }
    end

    context 'with an untracked pipeline' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: untracked_branch_ref.context_name) }

      it { is_expected.to be false }
    end

    context 'when no matching ref exists' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: 'non-existent-branch') }

      it { is_expected.to be false }
    end
  end

  describe '.find_default_branch_context' do
    let_it_be(:project_with_repository) { create(:project, :repository) }

    subject(:find_default_branch_context) { described_class.find_default_branch_context(project_with_repository) }

    context 'when a matching branch context exists' do
      let_it_be(:default_branch_context) do
        create(:security_project_tracked_context,
          project: project_with_repository,
          context_name: project_with_repository.default_branch,
          context_type: :branch
        )
      end

      it { is_expected.to eq(default_branch_context) }
    end

    context 'when no matching context exists' do
      it { is_expected.to be_nil }
    end
  end

  describe '.default_branch_contexts_by_project_id' do
    let_it_be(:project_with_repository) { create(:project, :repository) }
    let_it_be(:other_project_with_repository) { create(:project, :repository) }
    let_it_be(:unmatched_project) { create(:project, :repository) }

    let_it_be(:default_branch_context) do
      create(:security_project_tracked_context,
        project: project_with_repository,
        context_name: project_with_repository.default_branch,
        context_type: :branch
      )
    end

    let_it_be(:other_default_branch_context) do
      create(:security_project_tracked_context,
        project: other_project_with_repository,
        context_name: other_project_with_repository.default_branch,
        context_type: :branch
      )
    end

    subject(:default_branch_contexts_by_project_id) do
      described_class.default_branch_contexts_by_project_id(projects)
    end

    context 'with a single project' do
      let(:projects) { project_with_repository }

      it 'returns a hash indexed by project_id with the matching context' do
        expect(default_branch_contexts_by_project_id).to eq(
          project_with_repository.id => default_branch_context
        )
      end
    end

    context 'with multiple projects' do
      let(:projects) { [project_with_repository, other_project_with_repository] }

      it 'returns a hash indexed by project_id with all matching contexts in a single query' do
        recorder = ActiveRecord::QueryRecorder.new { default_branch_contexts_by_project_id }

        expect(recorder.count).to eq(1)
        expect(default_branch_contexts_by_project_id).to eq(
          project_with_repository.id => default_branch_context,
          other_project_with_repository.id => other_default_branch_context
        )
      end
    end

    context 'with a mix of matched and unmatched projects' do
      let(:projects) { [project_with_repository, other_project_with_repository, unmatched_project] }

      it 'returns only the projects with matching contexts' do
        expect(default_branch_contexts_by_project_id.keys).to contain_exactly(
          project_with_repository.id,
          other_project_with_repository.id
        )
      end
    end

    context 'when no matching context exists' do
      let(:projects) { unmatched_project }

      it { is_expected.to eq({}) }
    end

    context 'when an empty array is passed' do
      let(:projects) { [] }

      it 'returns an empty hash without querying the database' do
        recorder = ActiveRecord::QueryRecorder.new { default_branch_contexts_by_project_id }

        expect(recorder.count).to eq(0)
        expect(default_branch_contexts_by_project_id).to eq({})
      end
    end
  end

  shared_context 'with project with repository' do
    let_it_be_with_reload(:project_with_repo) { create(:project, :repository) }

    before_all do
      unless project_with_repo.repository.branch_exists?(project_with_repo.default_branch)
        commit_sha = project_with_repo.repository.commit(project_with_repo.default_branch).sha
        project_with_repo.repository.create_branch(project_with_repo.default_branch, commit_sha)
        project_with_repo.repository.expire_branches_cache
      end
    end
  end

  describe '#ref_exists_in_repository?' do
    include_context 'with project with repository'

    context 'when project has no repository' do
      let_it_be(:project_without_repo) { create(:project) }

      subject { create(:security_project_tracked_context, project: project_without_repo) }

      it { is_expected.not_to be_ref_exists_in_repository }
    end

    context 'with a branch context' do
      let_it_be(:context) do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: project_with_repo.default_branch)
      end

      it 'returns true when the branch exists' do
        expect(context.ref_exists_in_repository?).to be true
      end

      context 'when the branch does not exist' do
        let_it_be(:context) do
          create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
            context_name: 'nonexistent-branch')
        end

        it 'returns false' do
          expect(context.ref_exists_in_repository?).to be false
        end
      end
    end

    context 'with a tag context' do
      it 'returns true when the tag exists' do
        tag_name = "test-tag-ref-exists-#{SecureRandom.hex(4)}"
        user = create(:user)
        context = create(:security_project_tracked_context, project: project_with_repo, context_type: :tag,
          context_name: tag_name)

        commit = project_with_repo.repository.commit(project_with_repo.default_branch)
        project_with_repo.repository.add_tag(user, tag_name, commit.sha)

        expect(context.ref_exists_in_repository?).to be true
      end
    end

    context 'when tag does not exist' do
      subject do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :tag,
          context_name: 'nonexistent-tag-ref-exists')
      end

      it { is_expected.not_to be_ref_exists_in_repository }
    end

    context 'when project is nil' do
      subject do
        build(:security_project_tracked_context, project: nil, context_type: :branch, context_name: 'some-branch')
      end

      it { is_expected.not_to be_ref_exists_in_repository }
    end

    context 'when context_type is neither branch nor tag' do
      it 'returns false' do
        context = create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: project_with_repo.default_branch)

        allow(context).to receive(:context_type).and_return('commit')

        expect(context.ref_exists_in_repository?).to be false
      end
    end

    context 'when memoizing' do
      it 'memoizes the result' do
        context = create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: project_with_repo.default_branch)

        expect(project_with_repo.repository).to receive(:branch_exists?)
          .with(project_with_repo.default_branch).once.and_call_original

        2.times { context.ref_exists_in_repository? }
      end
    end
  end

  describe '#protected?' do
    include_context 'with project with repository'
    let_it_be(:user) { create(:user) }

    context 'when the ref does not exist in repository' do
      subject do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: 'nonexistent')
      end

      it { is_expected.not_to be_protected }
    end

    context 'with a branch context' do
      let_it_be(:context) do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: project_with_repo.default_branch)
      end

      context 'when the branch is protected' do
        before do
          create(:protected_branch, project: project_with_repo, name: project_with_repo.default_branch)
        end

        it 'returns true' do
          expect(context.protected?).to be true
        end
      end

      context 'when the branch is not protected' do
        it 'returns false' do
          expect(context.protected?).to be false
        end
      end
    end

    context 'with a tag context' do
      context 'when the tag is protected' do
        it 'returns true' do
          protected_tag_name = "test-tag-protected-#{SecureRandom.hex(4)}"
          commit = project_with_repo.repository.commit(project_with_repo.default_branch)
          project_with_repo.repository.add_tag(user, protected_tag_name, commit.sha)
          create(:protected_tag, project: project_with_repo, name: protected_tag_name)
          context_obj = create(:security_project_tracked_context, project: project_with_repo, context_type: :tag,
            context_name: protected_tag_name)

          expect(context_obj.protected?).to be true
        end
      end

      context 'when the tag is not protected' do
        it 'returns false' do
          unprotected_tag_name = "test-tag-unprotected-#{SecureRandom.hex(4)}"
          commit = project_with_repo.repository.commit(project_with_repo.default_branch)
          project_with_repo.repository.add_tag(user, unprotected_tag_name, commit.sha)
          context_obj = create(:security_project_tracked_context, project: project_with_repo, context_type: :tag,
            context_name: unprotected_tag_name)

          expect(context_obj.protected?).to be false
        end
      end
    end

    context 'when context_type is neither branch nor tag' do
      let_it_be(:context) do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: project_with_repo.default_branch)
      end

      it 'returns false' do
        allow(context).to receive_messages(context_type: 'commit', ref_exists_in_repository?: true)

        expect(context.protected?).to be false
      end
    end
  end

  describe '#commit' do
    include_context 'with project with repository'
    let_it_be(:user) { create(:user) }

    context 'when the ref does not exist in repository' do
      subject do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: 'nonexistent').commit
      end

      it { is_expected.to be_nil }
    end

    context 'with a branch context' do
      let_it_be(:context) do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: project_with_repo.default_branch)
      end

      it 'returns the commit' do
        expect(context.commit).to be_a(Commit)
        expect(context.commit.sha).to eq(project_with_repo.repository.commit(project_with_repo.default_branch).sha)
      end
    end

    context 'with a tag context' do
      it 'returns the commit' do
        tag_name = "test-tag-commit-#{SecureRandom.hex(4)}"
        tag_commit = project_with_repo.repository.commit(project_with_repo.default_branch)
        project_with_repo.repository.add_tag(user, tag_name, tag_commit.sha)
        context_obj = create(:security_project_tracked_context, project: project_with_repo, context_type: :tag,
          context_name: tag_name)

        expect(context_obj.commit).to be_a(Commit)
      end
    end

    context 'when context_type is neither branch nor tag' do
      let_it_be(:context) do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: project_with_repo.default_branch)
      end

      it 'returns nil' do
        allow(context).to receive_messages(context_type: 'commit', ref_exists_in_repository?: true)

        expect(context.commit).to be_nil
      end
    end

    shared_examples 'handles NoRepository error' do |error|
      let_it_be(:context) do
        create(:security_project_tracked_context, project: project_with_repo, context_type: :branch,
          context_name: project_with_repo.default_branch)
      end

      it 'tracks the error and returns nil' do
        allow(project_with_repo.repository).to receive(:commit).and_raise(error)

        expect(Gitlab::ErrorTracking).to receive(:track_exception)
        expect(context.commit).to be_nil
      end
    end

    context 'when repository raises NoRepository error without arguments' do
      it_behaves_like 'handles NoRepository error', Gitlab::Git::Repository::NoRepository.new
    end

    context 'when repository raises NoRepository error wrapping another exception' do
      it_behaves_like 'handles NoRepository error', Gitlab::Git::Repository::NoRepository.new(StandardError.new)
    end
  end

  describe 'context_aware_uuids_enabled?' do
    context 'when is_default is true' do
      let(:is_default) { true }

      context 'when uuid_version == 1' do
        subject(:tracked_context) do
          build(:security_project_tracked_context, is_default: is_default, project: project, uuid_version: 1)
        end

        it 'is false' do
          expect(tracked_context.context_aware_uuids_enabled?).to be_falsey
        end
      end

      context 'when uuid_version == 2' do
        subject(:tracked_context) do
          build(:security_project_tracked_context, is_default: is_default, project: project, uuid_version: 2)
        end

        it 'is true' do
          expect(tracked_context.context_aware_uuids_enabled?).to be_truthy
        end
      end
    end

    context 'when is_default is false' do
      let(:is_default) { false }

      context 'when uuid_version == 1' do
        subject(:tracked_context) do
          build(:security_project_tracked_context, is_default: is_default, project: project, uuid_version: 1)
        end

        it 'is true' do
          expect(tracked_context.context_aware_uuids_enabled?).to be_truthy
        end
      end

      context 'when uuid_version == 2' do
        subject(:tracked_context) do
          build(:security_project_tracked_context, is_default: is_default, project: project, uuid_version: 2)
        end

        it 'is true' do
          expect(tracked_context.context_aware_uuids_enabled?).to be_truthy
        end
      end
    end
  end
end
