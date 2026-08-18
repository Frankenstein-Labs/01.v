import { nextTick } from 'vue';
import { GlButton, GlFormSelect, GlFormInput } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import LinkForm from 'ee/cd/components/link_form.vue';

describe('LinkForm', () => {
  let wrapper;

  const GlFormSelectStub = stubComponent(GlFormSelect, {
    props: ['options'],
  });

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(LinkForm, {
      propsData: props,
      stubs: { GlFormSelect: GlFormSelectStub },
    });
  };

  const findSelect = () => wrapper.findComponent(GlFormSelect);
  const findInputs = () => wrapper.findAllComponents(GlFormInput);
  const findTitleInput = () => findInputs().at(0);
  const findUrlInput = () => findInputs().at(1);
  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findSubmitButton = () => findButtons().at(0);
  const findCancelButton = () => findButtons().at(1);
  const setTitle = (value) => findTitleInput().vm.$emit('input', value);
  const setUrl = (value) => findUrlInput().vm.$emit('input', value);
  const submitForm = () => wrapper.find('form').trigger('submit');

  describe('the type selector', () => {
    beforeEach(() => {
      createComponent();
    });

    it('includes every link type', () => {
      expect(findSelect().props('options')).toEqual([
        { value: 'RUNBOOK', text: 'Runbook' },
        { value: 'DASHBOARD', text: 'Dashboard' },
        { value: 'DOCS', text: 'Docs' },
        { value: 'REPOSITORY', text: 'Repository' },
        { value: 'CHAT', text: 'Chat / Slack' },
        { value: 'ISSUE_TRACKER', text: 'Issue tracker' },
        { value: 'ON_CALL', text: 'On-call rotation' },
        { value: 'CHANGE_REQUEST', text: 'Change / CR system' },
        { value: 'OTHER', text: 'Other' },
      ]);
    });

    it('defaults to Runbook', () => {
      expect(findSelect().attributes('value')).toBe('RUNBOOK');
    });
  });

  describe('the submit button', () => {
    beforeEach(() => {
      createComponent();
    });

    it('is labelled "Add link"', () => {
      expect(findSubmitButton().text()).toBe('Add link');
    });

    it('is enabled once a title and a valid URL are entered', async () => {
      expect(findSubmitButton().props('disabled')).toBe(true);

      setTitle('Grafana');
      setUrl('https://grafana.example.com');
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(false);
    });

    it('stays disabled when only the title is filled', async () => {
      setTitle('Grafana');
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it('shows the loading state while submitting', async () => {
      await wrapper.setProps({ submitting: true });

      expect(findSubmitButton().props('loading')).toBe(true);
    });
  });

  describe('when editing a link', () => {
    const link = {
      id: 'gid://gitlab/Cd::ApplicationLink/1',
      name: 'Existing docs',
      url: 'https://docs.example.com',
      linkType: 'DOCS',
    };

    beforeEach(() => {
      createComponent({ props: { link } });
    });

    it('prefills the fields from the link', () => {
      expect(findSelect().attributes('value')).toBe('DOCS');
      expect(findTitleInput().props('value')).toBe('Existing docs');
      expect(findUrlInput().props('value')).toBe('https://docs.example.com');
    });

    it('labels the submit button "Save changes"', () => {
      expect(findSubmitButton().text()).toBe('Save changes');
    });
  });

  describe('URL validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('leaves the field unflagged while it is empty', () => {
      expect(findUrlInput().props('state')).toBe(null);
    });

    it('flags a URL that is not http(s) and keeps submit disabled', async () => {
      setTitle('Grafana');
      setUrl('ftp://files.example.com');
      await nextTick();

      expect(findUrlInput().props('state')).toBe(false);
      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it('accepts an http(s) URL', async () => {
      setUrl('https://ok.example.com');
      await nextTick();

      expect(findUrlInput().props('state')).toBe(null);
    });
  });

  describe('when the form is submitted', () => {
    beforeEach(async () => {
      createComponent();
      setTitle('Grafana');
      setUrl('https://grafana.example.com');
      await nextTick();
      await submitForm();
    });

    it('emits submit with the field values', () => {
      expect(wrapper.emitted('submit')).toEqual([
        [{ linkType: 'RUNBOOK', name: 'Grafana', url: 'https://grafana.example.com' }],
      ]);
    });
  });

  describe('when cancel is clicked', () => {
    beforeEach(() => {
      createComponent();
      findCancelButton().vm.$emit('click');
    });

    it('emits cancel', () => {
      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });
});
