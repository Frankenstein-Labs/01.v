import { nextTick } from 'vue';
import { GlButton, GlFormGroup } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import ResetButton from 'ee/pages/admin/users/pipeline_minutes/reset_button.vue';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_SERVICE_UNAVAILABLE } from '~/lib/utils/http_status';
import { CONTEXT_TYPE } from '~/members/constants';

const defaultProvide = { resetMinutesPath: '/adming/reset_minutes' };
const $toast = {
  show: jest.fn(),
};

describe('Reset compute usage button', () => {
  let wrapper;
  let mock;

  const createComponent = (provide = {}) => {
    wrapper = mount(ResetButton, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
      mocks: {
        $toast,
      },
      stubs: {
        GlFormGroup: false,
      },
    });
  };

  beforeEach(() => {
    createComponent();
    mock = new MockAdapter(axios);
  });

  const findResetButton = () => wrapper.findComponent(GlButton);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);

  it('should render form group', () => {
    const formGroup = findFormGroup();

    expect(formGroup.exists()).toBe(true);
  });

  it('should contain a button with the "Reset compute usage" text', () => {
    const button = findResetButton();

    expect(button.text()).toBe('Reset compute usage');
  });

  describe('labelDescription', () => {
    it('defaults to group description when contextType is not provided', () => {
      const formGroup = findFormGroup();

      expect(formGroup.props('labelDescription')).toBe(
        'Changes the compute usage for this group to zero.',
      );
    });

    it('uses user description when contextType is CONTEXT_TYPE.USER', () => {
      createComponent({ contextType: CONTEXT_TYPE.USER });
      const formGroup = findFormGroup();

      expect(formGroup.props('labelDescription')).toBe(
        'Changes the compute usage for this user to zero.',
      );
    });

    it('uses group description when contextType is CONTEXT_TYPE.GROUP', () => {
      createComponent({ contextType: CONTEXT_TYPE.GROUP });
      const formGroup = findFormGroup();

      expect(formGroup.props('labelDescription')).toBe(
        'Changes the compute usage for this group to zero.',
      );
    });
  });

  describe('when the api is available', () => {
    beforeEach(() => {
      mock
        .onPost(defaultProvide.resetMinutesPath)
        .reply(HTTP_STATUS_OK, { status: HTTP_STATUS_OK });
    });

    afterEach(() => {
      mock.restore();
    });

    it('should create a network request when the reset button is clicked', async () => {
      const axiosSpy = jest.spyOn(axios, 'post');

      const button = findResetButton();

      button.vm.$emit('click');
      await nextTick();

      expect(button.props('loading')).toBe(true);

      await axios.waitForAll();

      expect(axiosSpy).toHaveBeenCalled();
      expect($toast.show).toHaveBeenCalledWith('Reset compute usage for this group.');
      expect(button.props('loading')).toBe(false);
    });

    it('shows correct toast message for user context', async () => {
      createComponent({ contextType: CONTEXT_TYPE.USER });
      mock
        .onPost(defaultProvide.resetMinutesPath)
        .reply(HTTP_STATUS_OK, { status: HTTP_STATUS_OK });

      const button = findResetButton();
      button.vm.$emit('click');

      await axios.waitForAll();

      expect($toast.show).toHaveBeenCalledWith('Reset compute usage for this user.');
    });
  });

  describe('when the api is not available', () => {
    beforeEach(() => {
      mock.onPost(defaultProvide.resetMinutesPath).reply(HTTP_STATUS_SERVICE_UNAVAILABLE, {
        status: HTTP_STATUS_SERVICE_UNAVAILABLE,
      });
    });

    afterEach(() => {
      mock.restore();
    });

    it('should show a toast error message', async () => {
      const axiosSpy = jest.spyOn(axios, 'post');

      const button = findResetButton();

      button.vm.$emit('click');

      await axios.waitForAll();

      expect(axiosSpy).toHaveBeenCalled();
      expect($toast.show).toHaveBeenCalledWith(
        'An error occurred while resetting the compute usage.',
      );
    });
  });
});
