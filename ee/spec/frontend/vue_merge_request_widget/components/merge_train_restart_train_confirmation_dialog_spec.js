import { GlSprintf } from '@gitlab/ui';
import { trimText } from 'helpers/text_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainRestartTrainConfirmationDialog from 'ee/vue_merge_request_widget/components/merge_train_restart_train_confirmation_dialog.vue';

describe('MergeTrainFailedPipelineConfirmationDialog', () => {
  let wrapper;

  const hideDropdown = jest.fn();

  const GlModal = {
    template: `
      <div>
        <slot></slot>
        <slot name="modal-footer"></slot>
      </div>
    `,
    methods: {
      hide: hideDropdown,
    },
  };

  const createComponent = (type = 'restart') => {
    wrapper = shallowMountExtended(MergeTrainRestartTrainConfirmationDialog, {
      propsData: {
        visible: true,
        mergeTrainType: type,
      },
      stubs: {
        GlModal,
        GlSprintf,
      },
      attachTo: document.body,
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findProcessMergeTrainBtn = () => wrapper.findComponentByTestId('process-merge-train');
  const findCancelBtn = () => wrapper.findComponent({ ref: 'cancelButton' });

  describe('When restarting the merge train', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should render informational text explaining why merging immediately can be dangerous', () => {
      expect(trimText(wrapper.text())).toMatchInterpolatedText(
        "Merging immediately is not recommended because your changes won't be validated by the merge train, and any running merge train pipelines will be restarted. What are the risks? Cancel Merge now and restart train",
      );
    });

    it('should emit the process-merge-train-merge event', () => {
      findProcessMergeTrainBtn().vm.$emit('click');

      expect(wrapper.emitted('process-merge-train-merge')).toHaveLength(1);
    });

    it('when the cancel button is clicked should emit cancel and call hide', () => {
      findCancelBtn().vm.$emit('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
      expect(hideDropdown).toHaveBeenCalled();
    });

    it('should emit cancel when the hide event is emitted', () => {
      findModal().vm.$emit('hide');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });

    it('when modal is shown it will focus the cancel button', () => {
      findCancelBtn().element.focus = jest.fn();

      findModal().vm.$emit('shown');

      expect(findCancelBtn().element.focus).toHaveBeenCalled();
    });
  });

  describe('When skipping the merge train', () => {
    beforeEach(() => {
      createComponent('skip');
    });

    it('should render informational text explaining why merging immediately can be dangerous', () => {
      expect(trimText(wrapper.text())).toContain(
        'Merging immediately is not recommended. The merged changes could cause pipeline failures on the target branch, and the changes will not be validated against the commits being added by the merge requests currently in the merge train. Read the documentation for more information.',
      );
    });
  });
});
