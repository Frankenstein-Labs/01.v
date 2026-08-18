# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::VersionSet, feature_category: :continuous_delivery do
  let_it_be(:application) { create(:cd_application) }

  describe 'associations' do
    it { is_expected.to belong_to(:application).required }
    it { is_expected.to belong_to(:created_by).class_name('User').optional }
    it { is_expected.to have_many(:version_set_entries) }
    it { is_expected.to have_many(:versions).through(:version_set_entries) }
    it { is_expected.to have_many(:rollout_environments) }
  end

  describe 'validations' do
    subject { build(:cd_version_set, application: application) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:description).is_at_most(2000) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }

    describe 'name format' do
      it { is_expected.to allow_value('my-version-set').for(:name) }
      it { is_expected.to allow_value('my_version_set').for(:name) }
      it { is_expected.to allow_value('MyVersionSet').for(:name) }
      it { is_expected.to allow_value('-versionset').for(:name) }
      it { is_expected.to allow_value('versionset-').for(:name) }
      it { is_expected.to allow_value('my version set').for(:name) }
      it { is_expected.to allow_value('versionset/name').for(:name) }
      it { is_expected.to allow_value('versionset.name').for(:name) }
      it { is_expected.to allow_value('versionset!').for(:name) }
    end

    it 'enforces uniqueness of name scoped to application_id' do
      create(:cd_version_set, application: application, name: 'release-1')

      expect { create(:cd_version_set, application: application, name: 'release-1') }
        .to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
    end

    it 'enforces uniqueness of entries_digest scoped to application_id, allowing nil' do
      create(:cd_version_set, application: application, name: 'release-1').update_column(:entries_digest, 'abc123')

      expect(build(:cd_version_set, application: application, name: 'release-2', entries_digest: 'abc123'))
        .not_to be_valid
      expect(build(:cd_version_set, application: application, name: 'release-3', entries_digest: nil)).to be_valid
    end
  end

  describe 'entries digest' do
    let_it_be(:version_set) { create(:cd_version_set, application: application) }
    let_it_be(:entry_a) { create(:cd_version_set_entry, version_set: version_set) }
    let_it_be(:entry_b) { create(:cd_version_set_entry, version_set: version_set) }

    describe '#compute_entries_digest' do
      it 'returns a stable SHA-256 hex digest of the entries' do
        digest = version_set.compute_entries_digest

        expect(digest).to match(/\A[0-9a-f]{64}\z/)
        expect(version_set.reload.compute_entries_digest).to eq(digest)
      end

      it 'returns nil when the version set has no entries' do
        expect(create(:cd_version_set, application: application).compute_entries_digest).to be_nil
      end

      it 'differs from a version set with different entries' do
        other = create(:cd_version_set, application: application)
        create(:cd_version_set_entry, version_set: other)

        expect(other.compute_entries_digest).not_to eq(version_set.compute_entries_digest)
      end
    end

    describe '#update_entries_digest!' do
      it 'persists the computed digest' do
        expected = version_set.compute_entries_digest

        expect { version_set.update_entries_digest! }
          .to change { version_set.reload.entries_digest }.from(nil).to(expected)
      end
    end
  end

  describe 'sharding key' do
    subject { build(:cd_version_set, application: application) }

    it { is_expected.to populate_sharding_key(:organization_id).with(application.organization_id) }
  end

  describe '.search' do
    let_it_be(:application) { create(:cd_application) }
    let_it_be(:payments_release) do
      create(:cd_version_set, application: application, name: 'payments-2-4', description: 'Billing and invoices')
    end

    let_it_be(:web_release) { create(:cd_version_set, application: application, name: 'web-3-0') }

    it 'matches on name' do
      expect(application.version_sets.search('payments')).to contain_exactly(payments_release)
    end

    it 'matches on description' do
      expect(application.version_sets.search('invoices')).to contain_exactly(payments_release)
    end
  end

  describe '#status and .for_statuses' do
    let_it_be(:release_without_rollouts) { create(:cd_version_set, application: application) }

    let_it_be(:deploying_release) { create(:cd_version_set, application: application) }
    let_it_be(:deploying_rollout) do
      create(:cd_rollout, version_set: deploying_release, application: application, state: :in_progress,
        workflow_ref: 'wk:1/deploying')
    end

    let_it_be(:failed_release) { create(:cd_version_set, application: application) }
    let_it_be(:failed_rollout) do
      create(:cd_rollout, version_set: failed_release, application: application, state: :failed,
        workflow_ref: 'wk:1/failed')
    end

    let_it_be(:current_release) { create(:cd_version_set, application: application) }
    let_it_be(:current_rollout) do
      create(:cd_rollout, version_set: current_release, application: application, state: :completed,
        workflow_ref: 'wk:1/current')
    end

    # superseded_release was deployed and later replaced by superseding_release.
    let_it_be(:superseded_release) { create(:cd_version_set, application: application) }
    let_it_be(:superseded_rollout) do
      create(:cd_rollout, version_set: superseded_release, application: application, state: :completed,
        workflow_ref: 'wk:1/superseded')
    end

    let_it_be(:superseding_release) { create(:cd_version_set, application: application) }
    let_it_be(:superseding_rollout) do
      create(:cd_rollout, version_set: superseding_release, application: application, state: :completed,
        workflow_ref: 'wk:1/superseding')
    end

    let_it_be(:superseding_rollout_environment) do
      create(:cd_rollout_environment, rollout: superseding_rollout, state: :completed,
        previous_version_set: superseded_release)
    end

    # rolled_back_release was deployed, superseded by an intervening release, then redeployed
    # (rolled back to) after that intervening release.
    let_it_be(:rolled_back_release) { create(:cd_version_set, application: application) }
    let_it_be(:rolled_back_first_rollout) do
      create(:cd_rollout, version_set: rolled_back_release, application: application, state: :completed,
        workflow_ref: 'wk:1/rolled-back-first')
    end

    let_it_be(:intervening_release) { create(:cd_version_set, application: application) }
    let_it_be(:intervening_rollout) do
      create(:cd_rollout, version_set: intervening_release, application: application, state: :completed,
        workflow_ref: 'wk:1/intervening')
    end

    let_it_be(:intervening_rollout_environment) do
      create(:cd_rollout_environment, rollout: intervening_rollout, state: :completed,
        previous_version_set: rolled_back_release)
    end

    let_it_be(:rollback_rollout) do
      create(:cd_rollout, version_set: rolled_back_release, application: application, state: :completed,
        workflow_ref: 'wk:1/rollback')
    end

    let_it_be(:rollback_rollout_environment) do
      create(:cd_rollout_environment, rollout: rollback_rollout, state: :completed,
        previous_version_set: intervening_release)
    end

    # redeployed_release is redeployed (e.g. to pick up an unrelated config
    # change) without any newer release having taken over in between, so its
    # rollout_environment's previous_version_set point back at itself.
    let_it_be(:redeployed_release) { create(:cd_version_set, application: application) }
    let_it_be(:redeployed_first_rollout) do
      create(:cd_rollout, version_set: redeployed_release, application: application, state: :completed,
        workflow_ref: 'wk:1/redeployed-first')
    end

    let_it_be(:redeployed_second_rollout) do
      create(:cd_rollout, version_set: redeployed_release, application: application, state: :completed,
        workflow_ref: 'wk:1/redeployed-second')
    end

    let_it_be(:redeployed_rollout_environment) do
      create(:cd_rollout_environment, rollout: redeployed_second_rollout, state: :completed,
        previous_version_set: redeployed_release)
    end

    describe '#status' do
      it 'returns nil when the version set has no rollouts' do
        expect(release_without_rollouts.status).to be_nil
      end

      it 'returns "deploying" when the latest rollout is not yet in a terminal state' do
        expect(deploying_release.status).to eq('deploying')
      end

      it 'returns nil when the latest rollout failed' do
        expect(failed_release.status).to be_nil
      end

      it 'returns nil when the version set is live and has not been replaced' do
        expect(current_release.status).to be_nil
      end

      it 'returns "superseded" when a later release has completed a rollout that replaced it' do
        expect(superseded_release.status).to eq('superseded')
      end

      it 'does not mark the superseding release itself as superseded' do
        expect(superseding_release.status).to be_nil
      end

      it 'returns "rolled_back" when the latest completed rollout replaced a newer release' do
        expect(rolled_back_release.status).to eq('rolled_back')
      end

      it 'does not mark the intervening release as rolled back' do
        expect(intervening_release.status).to eq('superseded')
      end

      it 'does not treat redeploying the same release as a rollback' do
        expect(redeployed_release.status).to be_nil
      end

      it 'breaks ties on id (not insertion order) when two rollouts share the same created_at' do
        # Uses its own application: an in_progress rollout is only allowed
        # to coexist with terminal-state rollouts within the same
        # application (see index_cd_rollouts_on_application_id_non_terminal).
        tied_application = create(:cd_application)
        tied_release = create(:cd_version_set, application: tied_application)
        tied_at = Time.current

        earlier_by_id_rollout = create(:cd_rollout, version_set: tied_release, application: tied_application,
          state: :failed, workflow_ref: 'wk:1/tied-first', created_at: tied_at)
        later_by_id_rollout = create(:cd_rollout, version_set: tied_release, application: tied_application,
          state: :in_progress, workflow_ref: 'wk:1/tied-second', created_at: tied_at)

        expect(earlier_by_id_rollout.created_at).to eq(later_by_id_rollout.created_at)
        expect(later_by_id_rollout.id).to be > earlier_by_id_rollout.id
        expect(tied_release.status).to eq('deploying')
      end
    end

    describe '.statuses_by_id' do
      it 'returns a hash keyed by id, omitting version sets with no computed status' do
        ids = [
          release_without_rollouts, deploying_release, failed_release, current_release,
          superseded_release, superseding_release, rolled_back_release, intervening_release
        ].map(&:id)

        expect(described_class.statuses_by_id(ids)).to eq(
          deploying_release.id => 'deploying',
          superseded_release.id => 'superseded',
          rolled_back_release.id => 'rolled_back',
          intervening_release.id => 'superseded'
        )
      end
    end

    describe '.for_statuses' do
      it 'returns version sets matching a single given status' do
        expect(application.version_sets.for_statuses(%w[deploying])).to contain_exactly(deploying_release)
      end

      it 'returns the union of version sets when multiple statuses are given' do
        expect(application.version_sets.for_statuses(%w[superseded rolled_back])).to contain_exactly(
          superseded_release, rolled_back_release, intervening_release
        )
      end

      it 'ignores unknown statuses instead of raising or matching everything' do
        expect(application.version_sets.for_statuses(%w[bogus])).to be_empty
      end

      it 'does not let an unknown status affect matching on other given statuses' do
        expect(application.version_sets.for_statuses(%w[deploying bogus])).to contain_exactly(deploying_release)
      end
    end
  end
end
