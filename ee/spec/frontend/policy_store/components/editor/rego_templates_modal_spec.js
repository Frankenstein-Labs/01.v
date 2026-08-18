import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { GlModal, GlSearchBoxByType } from '@gitlab/ui';
import RegoTemplatesModal from 'ee/policy_store/components/editor/rego_templates_modal.vue';
import { REGO_TEMPLATES } from 'ee/policy_store/catalog/rego_templates';

describe('RegoTemplatesModal', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(RegoTemplatesModal, {
      propsData: { visible: true, ...propsData },
      stubs: { GlModal: { template: '<div><slot /></div>' } },
    });
  };

  const findCards = () => wrapper.findAll('[data-testid="rego-template-card"]');

  it('renders a card for every template', () => {
    createComponent();

    expect(findCards()).toHaveLength(REGO_TEMPLATES.length);
    expect(wrapper.text()).toContain('Deployment Gate');
  });

  it('filters templates by search query', async () => {
    createComponent();

    wrapper.findComponent(GlSearchBoxByType).vm.$emit('input', 'deployment');
    await nextTick();

    expect(wrapper.text()).toContain('Deployment Gate');
    expect(wrapper.text()).not.toContain('Blank Template');
  });

  it('emits select with the template rego and hide when a card is clicked', async () => {
    createComponent();

    await findCards().at(0).trigger('click');

    expect(wrapper.emitted('select')[0]).toEqual([REGO_TEMPLATES[0].rego]);
    expect(wrapper.emitted('hide')).toHaveLength(1);
  });

  it('emits hide when the modal is dismissed', () => {
    createComponent();

    wrapper.findComponent(GlModal).vm.$emit('hidden');

    expect(wrapper.emitted('hide')).toHaveLength(1);
  });
});
