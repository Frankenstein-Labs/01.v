# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::CommitSignature, feature_category: :source_code_management do
  let_it_be(:gpg_key) { create(:gpg_key) }

  describe '#verified_committer?' do
    context 'when verification_status is verified_ca' do
      it 'returns true' do
        signature = build(:gpg_signature, gpg_key: gpg_key, verification_status: :verified_ca)

        expect(signature.verified_committer?).to be(true)
      end
    end
  end
end
