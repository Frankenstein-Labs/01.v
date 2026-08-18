import { GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import { stubComponent } from 'helpers/stub_component';

import DeleteModal from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/delete_modal.vue';

describe('Compliance framework delete modal', () => {
  let wrapper;

  const showModal = jest.fn();
  const createComponent = () => {
    wrapper = shallowMount(DeleteModal, {
      propsData: {
        name: 'test',
      },
      stubs: {
        GlModal: stubComponent(GlModal, {
          methods: {
            show: showModal,
          },
        }),
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('exposes show method which calls underlying GlModal', () => {
    wrapper.vm.show();

    expect(showModal).toHaveBeenCalled();
  });

  it('emits "delete" event when underlying modal emits primary event', () => {
    wrapper.findComponent(GlModal).vm.$emit('primary');

    expect(wrapper.emitted('delete')).toHaveLength(1);
  });
});
