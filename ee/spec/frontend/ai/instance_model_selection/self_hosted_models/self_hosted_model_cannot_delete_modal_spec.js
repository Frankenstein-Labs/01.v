import { GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import CannotDeleteModal from 'ee/ai/instance_model_selection/self_hosted_models/components/self_hosted_model_cannot_delete_modal.vue';
import { INSTANCE_MODEL_SELECTION_ROUTE_NAMES } from 'ee/ai/instance_model_selection/constants';
import { mockSelfHostedModelsList } from './mock_data';

jest.mock('~/lib/utils/url_utility');

const MOCK_MODAL_ID = 'cannot-delete-mock-model-modal';
const mockModel = mockSelfHostedModelsList[0]; // with feature settings

describe('CannotDeleteModal', () => {
  let wrapper;
  const $router = {
    push: jest.fn(),
  };

  const createComponent = () => {
    wrapper = shallowMount(CannotDeleteModal, {
      propsData: {
        id: MOCK_MODAL_ID,
        model: mockModel,
      },
      stubs: { GlModal, GlSprintf },
      mocks: {
        $router,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  beforeEach(() => {
    createComponent();
  });

  it('displays the correct title', () => {
    expect(findModal().props('title')).toBe('This self-hosted model cannot be deleted');
  });

  it('sets modal id', () => {
    expect(findModal().props('modalId')).toBe(MOCK_MODAL_ID);
  });

  it('displays the correct body', () => {
    const body = findModal().text();
    expect(body).toContain('mock-self-hosted-model-1');
    expect(body).toContain('Code Completion');
  });

  it('renders primary button', () => {
    expect(findModal().props('actionPrimary').text).toBe('View AI-native features');
  });

  it('renders a cancel button', () => {
    expect(findModal().props('actionCancel').text).toBe('Cancel');
  });

  it('navigates to AI features tab on primary button click', () => {
    findModal().vm.$emit('primary');

    expect($router.push).toHaveBeenCalledTimes(1);
    expect($router.push).toHaveBeenCalledWith({
      name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.FEATURES,
    });
  });
});
