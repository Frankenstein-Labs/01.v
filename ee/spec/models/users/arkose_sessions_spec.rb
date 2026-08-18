# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::ArkoseSession, :saas, feature_category: :instance_resiliency do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:session_xid) }
    it { is_expected.to validate_length_of(:session_xid).is_at_most(64) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:verified_at) }
    it { is_expected.to validate_length_of(:telltale_user).is_at_most(128) }
    it { is_expected.to validate_length_of(:user_agent).is_at_most(255) }
    it { is_expected.to validate_length_of(:user_language_shown).is_at_most(64) }
    it { is_expected.to validate_length_of(:device_xid).is_at_most(64) }
    it { is_expected.to validate_length_of(:ja4_hash).is_at_most(64) }
    it { is_expected.to validate_numericality_of(:canvas_fingerprint).only_integer.allow_nil }
    it { is_expected.to validate_presence_of(:telltale_list) }
    it { is_expected.to validate_length_of(:user_ip).is_at_most(64) }
    it { is_expected.to validate_length_of(:country).is_at_most(64) }
    it { is_expected.to validate_length_of(:region).is_at_most(64) }
    it { is_expected.to validate_length_of(:city).is_at_most(64) }
    it { is_expected.to validate_length_of(:isp).is_at_most(128) }
    it { is_expected.to validate_length_of(:connection_type).is_at_most(64) }
    it { is_expected.to validate_length_of(:risk_band).is_at_most(64) }
    it { is_expected.to validate_length_of(:risk_category).is_at_most(64) }
    it { is_expected.to validate_numericality_of(:global_score).only_integer.allow_nil }
    it { is_expected.to validate_numericality_of(:custom_score).only_integer.allow_nil }

    it 'validates session_xid is not Unavailable' do
      is_expected.to validate_exclusion_of(:session_xid)
        .in_array(["Unavailable"])
        .with_message("Session ID cannot be nil or 'Unavailable'")
    end
  end

  describe '.create_for_user_from_verify_response' do
    let(:user) { create(:user) }
    # `freeze: false` is required in this spec: one or more `let_it_be` subjects
    # cannot be frozen by default (deep_freeze traversal failure, a non-AR
    # subject, or an in-memory mutation that survives reload/refind). Do not
    # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
    # (see gitlab-org/gitlab#602925).
    let_it_be(:json_verify_response, freeze: false) do
      Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/successfully_solved_ec_response.json')))
    end

    let(:verify_response) { Arkose::VerifyResponse.new(json_verify_response) }

    subject(:arkose_session) { described_class.create_for_user_from_verify_response(user, verify_response) }

    it 'creates an ArkoseSession from a valid verify response' do
      expect(arkose_session).to be_persisted
    end

    context 'when verify response has empty telltale list' do
      let_it_be(:json_verify_response, freeze: false) do
        json_verify_response.tap do |response|
          response['session_details']['telltale_list'] = []
        end
      end

      it 'creates an ArkoseSession from a valid verify response with no telltales' do
        expect(arkose_session).to be_persisted
        expect(arkose_session.reload.telltale_list).to eq []
      end
    end

    context 'when verify response is invalid' do
      let_it_be(:json_verify_response, freeze: false) do
        Gitlab::Json.parse(File.read(Rails.root.join('ee/spec/fixtures/arkose/invalid_token.json')))
      end

      it 'does not create an ArkoseSession from an invalid verify response' do
        expect(arkose_session).not_to be_persisted
      end
    end
  end
end
