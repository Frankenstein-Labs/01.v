import { GlLink, GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DeleteCarModalConfirmation from 'ee/ci/merge_trains/components/delete_car_modal_confirmation.vue';
import { MODAL_ID } from 'ee/ci/merge_trains/constants';

describe('MergeTrainsTable', () => {
  let wrapper;

  const mergeRequestTitle = 'Hello world';

  const createComponent = () => {
    wrapper = shallowMountExtended(DeleteCarModalConfirmation, {
      propsData: {
        mergeRequestTitle,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findDocsLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('modal contains correct props', () => {
    expect(findModal().props()).toMatchObject({
      modalId: MODAL_ID,
      title: 'Remove from merge train',
      actionPrimary: {
        attributes: {
          variant: 'danger',
        },
        text: 'Remove from merge train',
      },
      actionCancel: {
        text: 'Cancel',
      },
    });
  });

  it('contains link to docs', () => {
    expect(findDocsLink().attributes('href')).toBe(
      '/help/ci/pipelines/merge_trains#remove-a-merge-request-from-a-merge-train',
    );
  });

  it('emits remove-car-confirmed event', () => {
    findModal().vm.$emit('primary');

    expect(wrapper.emitted()).toEqual({ 'remove-car-confirmed': [[]] });
  });

  it('modal contains reference to merge request title', () => {
    expect(wrapper.text()).toContain(mergeRequestTitle);
  });
});
