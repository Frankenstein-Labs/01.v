# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::ResponseCheck do
  describe 'validations' do
    let(:name_id) { '123-456-789' }
    let(:name_id_format) { 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent' }
    let(:xml_validation_errors) { [] }
    let(:xml_response) { double(:xml_response, name_id: name_id, name_id_format: name_id_format, valid?: xml_validation_errors.blank?, errors: xml_validation_errors) }

    subject(:check) { described_class.new(xml_response: xml_response) }

    before do
      check.valid?
    end

    context 'with blank NameID' do
      let(:name_id) { '' }

      it 'adds an error' do
        expect(check.errors[:name_id].join).to include('blank')
      end
    end

    context "when NameID doesn't match the stored value" do
      let(:identity) { double(:identity, extern_uid: '987') }

      subject(:check) { described_class.new(identity: identity, xml_response: xml_response) }

      it 'warns that NameID has changed and will break sign in' do
        expect(check.errors[:name_id].join).to include('must match stored NameID')
        expect(check.errors[:name_id].join).to include('allow sign in')
      end
    end

    context 'with non-persistent NameID Format' do
      let(:name_id_format) { 'urn:oasis:names:tc:SAML:2.0:nameid-format:transient' }

      it 'adds a warning' do
        expect(check.errors[:name_id_format].join).to include('persistent')
      end
    end

    context 'with email for NameID and format' do
      let(:name_id) { 'user@example.com' }
      let(:name_id_format) { 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress' }

      it "only warns on the NameID but not the format" do
        expect(check.errors[:name_id].join).to include('email')
        expect(check.errors[:name_id_format]).to be_blank
      end

      context 'with a stored NameID' do
        let(:identity) { double(:identity, extern_uid: 'user@example.com') }

        subject(:check) { described_class.new(identity: identity, xml_response: xml_response) }

        it "doesn't warn because making changes will break SSO" do
          expect(check.errors).to be_blank
        end
      end
    end

    context 'with an invalid XML response' do
      let(:xml_validation_errors) { ['Fingerprint mismatch'] }

      it 'reuses the validation errors from ruby-saml' do
        expect(check.errors[:xml_response]).to eq xml_validation_errors
      end
    end
  end
end
