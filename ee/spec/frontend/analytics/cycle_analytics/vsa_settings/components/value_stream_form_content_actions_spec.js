import ValueStreamFormContentActions from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content_actions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ValueStreamFormContentActions', () => {
  const vsaPath = '/mockVsaPath/test';

  let wrapper;

  const findPrimaryBtn = () => wrapper.findComponentByTestId('primary-button');
  const findCancelBtn = () => wrapper.findComponentByTestId('cancel-button');

  const createComponent = ({ props = {}, valueStreamGid = '' } = {}) => {
    wrapper = shallowMountExtended(ValueStreamFormContentActions, {
      provide: { vsaPath, valueStreamGid },
      propsData: {
        ...props,
      },
    });
  };

  describe.each`
    valueStreamGid                   | text                   | cancelHref
    ${''}                            | ${'New value stream'}  | ${vsaPath}
    ${'gid://gitlab/ValueStream/13'} | ${'Save value stream'} | ${`/mockVsaPath/test?value_stream_id=13`}
  `('when `valueStreamGid` is `$valueStreamGid`', ({ valueStreamGid, text, cancelHref }) => {
    beforeEach(() => {
      createComponent({ valueStreamGid });
    });

    it('renders primary action correctly', () => {
      expect(findPrimaryBtn().text()).toBe(text);
      expect(findPrimaryBtn().props()).toMatchObject({
        variant: 'confirm',
        loading: false,
        disabled: false,
      });
    });

    it('emits `click-primary-action` event when primary action is selected', () => {
      findPrimaryBtn().vm.$emit('click');

      expect(wrapper.emitted('click-primary-action')).toHaveLength(1);
    });

    it('renders cancel button link correctly', () => {
      expect(findCancelBtn().props('disabled')).toBe(false);
      expect(findCancelBtn().attributes('href')).toBe(cancelHref);
    });

    describe('isLoading=true', () => {
      beforeEach(() => {
        createComponent({ valueStreamGid, props: { isLoading: true } });
      });

      it('sets primary action to a loading state', () => {
        expect(findPrimaryBtn().props('loading')).toBe(true);
      });

      it('disables all other actions', () => {
        expect(findCancelBtn().props('disabled')).toBe(true);
      });
    });
  });
});
