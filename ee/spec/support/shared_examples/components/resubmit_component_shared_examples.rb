# frozen_string_literal: true

RSpec.shared_examples 'resubmit component' do
  let(:hidden_fields) do
    {
      field_one: 'field one',
      field_two: 'field two'
    }
  end

  let(:submit_path) { '/some/path' }
  let(:kwargs) do
    {
      hidden_fields: hidden_fields,
      submit_path: submit_path
    }
  end

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  context 'with default content' do
    it 'displays the error title' do
      is_expected.to have_content('Trial registration unsuccessful')
    end

    it 'displays the error message' do
      is_expected.to have_content(_("We're sorry, your trial could not be created. Please resubmit"))
    end

    it 'displays the resubmit button' do
      is_expected.to have_content(_('Resubmit request'))
    end

    it 'has the correct form action attribute' do
      form = find_by_testid('trial-form', context: component)

      expect(form['action']).to eq(submit_path)
    end

    it 'has the correct form method' do
      form = find_by_testid('trial-form', context: component)

      expect(form['method']).to eq('post')
    end

    it 'renders all hidden fields' do
      within(find_by_testid('trial-form', context: component)) do
        hidden_fields.each do |field, value|
          expect(page).to have_selector("input[type='hidden'][name='#{field}'][value='#{value}']")
        end
      end
    end
  end

  context 'with empty hidden fields' do
    let(:hidden_fields) { {} }

    it 'still renders the form without hidden fields' do
      has_testid?('trial-form', context: component)
      is_expected.not_to have_selector("input[type='hidden']")
    end
  end
end

RSpec.shared_examples 'resubmit component with data attributes' do
  let(:hidden_fields) { { field_one: 'value' } }
  let(:submit_path) { '/some/path' }

  subject(:component) { render_inline(described_class.new(hidden_fields: hidden_fields, submit_path: submit_path)) }

  it 'does not include data attributes on the resubmit button' do
    expect(component).not_to have_selector('button[type="submit"][data-event-tracking]')
  end
end
