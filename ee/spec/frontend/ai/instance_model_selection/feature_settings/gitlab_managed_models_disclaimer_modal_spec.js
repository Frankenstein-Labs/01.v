import { GlFormCheckbox, GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';
import { SUPPRESS_GITLAB_MANAGED_MODELS_DISCLAIMER_MODAL_KEY } from 'ee/ai/instance_model_selection/feature_settings/constants';
import GitlabManagedModelsDisclaimerModal from 'ee/ai/instance_model_selection/feature_settings/components/gitlab_managed_models_disclaimer_modal.vue';

const MOCK_SELECTED_OPTION = {
  value: 'gid://gitlab/Ai::Model/26',
  text: 'GitLab Managed Model',
};

describe('GitlabManagedModelsDisclaimerModal', () => {
  useLocalStorageSpy();

  let wrapper;
  const mockHideModal = jest.fn();
  const mockShowModal = jest.fn();

  const createComponent = () => {
    wrapper = shallowMountExtended(GitlabManagedModelsDisclaimerModal, {
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
          methods: {
            show: mockShowModal,
            hide: mockHideModal,
          },
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findModalGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findCancelButton = () => wrapper.findByTestId('cancel-button');
  const findConfirmButton = () => wrapper.findComponentByTestId('confirm-button');
  const findModalDismissCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  beforeEach(() => {
    createComponent();
  });

  it('renders the correct title and description', () => {
    expect(findModal().props('title')).toMatch('GitLab managed model');
    expect(findModalGlSprintf().attributes('message')).toMatch(
      'By selecting %{selectedGitlabManagedModel}, you consent to using a GitLab managed model and sending data to the GitLab AI gateway.',
    );
  });

  it('has a confirm button', () => {
    expect(findConfirmButton().exists()).toBe(true);
  });

  it('has a cancel button', () => {
    expect(findCancelButton().exists()).toBe(true);
  });

  it('has a modal dismiss checkbox', () => {
    expect(findModalDismissCheckbox().exists()).toBe(true);
  });

  describe('showModal', () => {
    describe('when "do not show again" checkbox was previously checked', () => {
      beforeEach(() => {
        localStorage.setItem(SUPPRESS_GITLAB_MANAGED_MODELS_DISCLAIMER_MODAL_KEY, 'true');
        wrapper.vm.showModal(MOCK_SELECTED_OPTION);
      });

      it('does not show the modal', () => {
        expect(mockShowModal).not.toHaveBeenCalled();
      });

      it('emits `confirm` event', () => {
        expect(wrapper.emitted('confirm')).toStrictEqual([[MOCK_SELECTED_OPTION.value]]);
      });
    });

    describe('when "do not show again" checkbox was not previously checked', () => {
      beforeEach(() => {
        wrapper.vm.showModal(MOCK_SELECTED_OPTION);
      });

      it('shows the modal', () => {
        expect(mockShowModal).toHaveBeenCalledTimes(1);
      });

      it('does not emit `confirm` event', () => {
        expect(wrapper.emitted('confirm')).toBeUndefined();
      });
    });
  });

  describe('onSubmit', () => {
    beforeEach(() => {
      wrapper.vm.showModal(MOCK_SELECTED_OPTION);
    });

    describe('when the "do not show again" checkbox is not checked', () => {
      beforeEach(() => {
        findConfirmButton().vm.$emit('click');
      });

      it('does not set item in localStorage', () => {
        expect(localStorage.setItem).not.toHaveBeenCalled();
      });

      it('emits `confirm` event', () => {
        expect(wrapper.emitted('confirm')).toStrictEqual([[MOCK_SELECTED_OPTION.value]]);
      });

      it('closes the modal', () => {
        expect(mockHideModal).toHaveBeenCalled();
      });
    });

    describe('when the "do not show again" checkbox is checked', () => {
      beforeEach(() => {
        findModalDismissCheckbox().vm.$emit('input', true);
        findConfirmButton().vm.$emit('click');
      });

      it('sets item in localStorage', () => {
        expect(localStorage.setItem).toHaveBeenCalledWith(
          SUPPRESS_GITLAB_MANAGED_MODELS_DISCLAIMER_MODAL_KEY,
          'true',
        );
      });

      it('emits `confirm` event', () => {
        expect(wrapper.emitted('confirm')).toStrictEqual([[MOCK_SELECTED_OPTION.value]]);
      });

      it('closes the modal', () => {
        expect(mockHideModal).toHaveBeenCalled();
      });
    });
  });
});
