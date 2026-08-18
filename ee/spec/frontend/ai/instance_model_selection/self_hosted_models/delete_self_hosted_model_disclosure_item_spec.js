import { GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMount, createWrapper } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

import { BV_SHOW_MODAL } from '~/lib/utils/constants';

import DeleteSelfHostedModelDisclosureItem from 'ee/ai/instance_model_selection/self_hosted_models/components/delete_self_hosted_model_disclosure_item.vue';
import DeleteModal from 'ee/ai/instance_model_selection/self_hosted_models/components/self_hosted_model_delete_modal.vue';
import CannotDeleteModal from 'ee/ai/instance_model_selection/self_hosted_models/components/self_hosted_model_cannot_delete_modal.vue';

import { mockSelfHostedModelsList } from './mock_data';

describe('DeleteSelfHostedModelDisclosureItem', () => {
  let wrapper;

  const modelWithFeatureSettings = mockSelfHostedModelsList[0];
  const modelWithoutFeatureSettings = mockSelfHostedModelsList[1];

  const createComponent = (props = {}) => {
    wrapper = extendedWrapper(
      shallowMount(DeleteSelfHostedModelDisclosureItem, {
        propsData: {
          model: modelWithoutFeatureSettings,
          ...props,
        },
      }),
    );
  };

  const findDisclosureDeleteButton = () => wrapper.findComponent(GlDisclosureDropdownItem);
  const findDeleteModal = () => wrapper.findComponent(DeleteModal);
  const findCannotDeleteModal = () => wrapper.findComponent(CannotDeleteModal);

  it('renders the disclosure delete button', () => {
    createComponent();

    expect(findDisclosureDeleteButton().text()).toBe('Delete');
  });

  describe('when model can be deleted', () => {
    const expectedModalId = `delete-${modelWithoutFeatureSettings.name}-model-modal`;

    beforeEach(() => {
      createComponent();
    });

    it('opens the delete modal when the disclosure button is clicked', async () => {
      await findDisclosureDeleteButton().trigger('click');

      const showModalEmitted = createWrapper(wrapper.vm.$root).emitted(BV_SHOW_MODAL);
      expect(showModalEmitted).toHaveLength(1);
      const modalId = showModalEmitted[0][0];
      expect(modalId).toBe(expectedModalId);
    });

    it('renders delete modal', () => {
      expect(findDeleteModal().exists()).toBe(true);
      expect(findDeleteModal().props('id')).toBe(expectedModalId);
    });

    it('does not render cannot delete modal', () => {
      expect(findCannotDeleteModal().exists()).toBe(false);
    });
  });

  describe('when model cannot be deleted', () => {
    const expectedModalId = `cannot-delete-${modelWithFeatureSettings.name}-model-modal`;

    beforeEach(() => {
      createComponent({ model: modelWithFeatureSettings });
    });

    it('opens the cannot delete modal when the disclosure button is clicked', async () => {
      await findDisclosureDeleteButton().trigger('click');

      const showModalEmitted = createWrapper(wrapper.vm.$root).emitted(BV_SHOW_MODAL);
      expect(showModalEmitted).toHaveLength(1);
      const modalId = showModalEmitted[0][0];
      expect(modalId).toBe(expectedModalId);
    });

    it('renders cannot delete modal', () => {
      expect(findCannotDeleteModal().exists()).toBe(true);
      expect(findCannotDeleteModal().props('id')).toBe(expectedModalId);
    });

    it('does not render delete modal', () => {
      expect(findDeleteModal().exists()).toBe(false);
    });
  });
});
