# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Audit::ImpersonatedAuthorPolicy, feature_category: :compliance_management do
  let(:user) { build :user }
  let(:impersonated_user) { build :user }
  let(:impersonated_author) { Gitlab::Audit::ImpersonatedAuthor.new impersonated_user }

  subject(:imp_policy) { described_class.new(user, impersonated_author) }

  context 'when checking read_user permission' do
    context 'when current user is another user' do
      it { is_expected.to be_allowed(:read_user) }
    end

    context 'when current user is admin' do
      let(:user) { build :admin }

      it { is_expected.to be_allowed(:read_user) }
    end

    context 'when current user is nil' do
      let(:user) { nil }

      it { is_expected.to be_allowed(:read_user) }
    end
  end
end
