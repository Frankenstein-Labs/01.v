# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationLink, feature_category: :continuous_delivery do
  describe 'associations' do
    it { is_expected.to belong_to(:application).required }
    it { is_expected.to belong_to(:organization).required }
  end

  describe 'validations' do
    subject { create(:cd_application_link) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_length_of(:url).is_at_most(2048) }
    it { is_expected.to validate_uniqueness_of(:url).scoped_to(:application_id) }
    it { is_expected.to validate_presence_of(:link_type) }

    it { is_expected.to allow_value('https://example.com/runbook').for(:url) }
    it { is_expected.to allow_value('http://localhost:3000/dashboard').for(:url) }
    it { is_expected.not_to allow_value('javascript:alert(1)').for(:url) }
    it { is_expected.not_to allow_value('ftp://example.com').for(:url) }
    it { is_expected.not_to allow_value('not a url').for(:url) }

    it 'defines the fixed list of link types' do
      is_expected.to define_enum_for(:link_type).with_values(
        runbook: 0,
        dashboard: 1,
        docs: 2,
        repository: 3,
        chat: 4,
        issue_tracker: 5,
        on_call: 6,
        change_request: 7,
        other: 8
      )
    end

    describe 'sharding key' do
      it 'is invalid without an organization' do
        link = build(:cd_application_link, organization: nil)

        expect(link).not_to be_valid
      end
    end

    describe '#application_belongs_to_organization' do
      let(:application) { create(:cd_application) }

      it 'is valid when the organization matches the application' do
        link = build(:cd_application_link, application: application, organization: application.organization)

        expect(link).to be_valid
      end

      it 'is invalid when the organization differs from the application' do
        other_organization = create(:organization)
        link = build(:cd_application_link, application: application, organization: other_organization)

        expect(link).not_to be_valid
        expect(link.errors[:application]).to include('must belong to the same organization.')
      end
    end
  end
end
