import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import toast from '~/vue_shared/plugins/global_toast';
import axios from '~/lib/utils/axios_utils';
import DuoOtelInfo from 'ee/pages/projects/show/components/duo_otel_info.vue';

jest.mock('~/alert');
jest.mock('~/vue_shared/plugins/global_toast');
jest.mock('~/lib/utils/axios_utils');

describe('DuoOtelInfo', () => {
  let wrapper;

  const createWorkflowPath = '/project/namespace/name/-/duo_otel_workflows';

  const findButton = () => wrapper.findComponent(GlButton);

  const createComponent = () => {
    wrapper = shallowMountExtended(DuoOtelInfo, {
      propsData: {
        createWorkflowPath,
      },
    });
  };

  beforeEach(() => {
    axios.post = jest.fn();
  });

  it('renders a button to start the OTel workflow', () => {
    createComponent();

    expect(findButton().exists()).toBe(true);
    expect(findButton().text()).toBe('Add OpenTelemetry with Duo');
  });

  describe('when the button is clicked', () => {
    it('sends a POST request to the workflow path', async () => {
      axios.post.mockResolvedValue({});
      createComponent();

      findButton().vm.$emit('click');
      await waitForPromises();

      expect(axios.post).toHaveBeenCalledWith(createWorkflowPath);
    });

    describe('while the request is pending', () => {
      it('disables the button with loading state', async () => {
        axios.post.mockReturnValue(new Promise(() => {}));
        createComponent();

        expect(findButton().props('loading')).toBe(false);

        findButton().vm.$emit('click');
        await nextTick();

        expect(findButton().props('loading')).toBe(true);
      });
    });

    describe('when the request succeeds', () => {
      beforeEach(async () => {
        axios.post.mockResolvedValue({});
        createComponent();

        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows a success message', () => {
        expect(toast).toHaveBeenCalledWith('OpenTelemetry workflow started');
      });

      it('re-enables the button', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });

    describe('when the request fails', () => {
      beforeEach(async () => {
        jest.spyOn(Sentry, 'captureException');
        axios.post.mockRejectedValue(new Error('Network error'));
        createComponent();

        findButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows the error message', () => {
        expect(createAlert).toHaveBeenCalledWith({ message: 'Failed to start workflow' });
      });

      it('captures the exception in Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });

      it('re-enables the button', () => {
        expect(findButton().props('loading')).toBe(false);
      });
    });
  });
});
