# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserPermissionExportUpload, type: :model do
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:upload, freeze: false) { build(:user_permission_export_upload) }

  subject { upload }

  describe 'associations' do
    it { is_expected.to belong_to(:user).conditions(admin: true) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }

    context 'when status is finished' do
      before do
        allow(upload).to receive(:finished?).and_return true
      end

      it 'validates file presence' do
        expect(upload).not_to be_valid
        expect(upload.errors.full_messages).to include("File can't be blank")
      end
    end
  end

  describe 'state transitions' do
    using RSpec::Parameterized::TableSyntax

    where(:status, :can_start, :can_finish, :can_fail) do
      0 | true  | false | true
      1 | false | true  | true
      2 | false | false | false
      3 | false | false | false
    end

    with_them do
      it 'adheres to state machine rules', :aggregate_failures do
        upload.status = status

        expect(upload.can_start?).to eq(can_start)
        expect(upload.can_finish?).to eq(can_finish)
        expect(upload.can_failed?).to eq(can_fail)
      end
    end
  end

  describe '#uploads_sharding_key' do
    it 'returns user_id' do
      user = create(:user)
      upload.user = user
      expect(upload.uploads_sharding_key).to eq({ uploaded_by_user_id: user.id })
    end
  end
end
