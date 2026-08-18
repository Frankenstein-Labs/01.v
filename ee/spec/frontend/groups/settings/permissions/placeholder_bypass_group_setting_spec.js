import { GlDatepicker } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import PlaceholderBypassGroupSetting from 'ee/groups/settings/permissions/components/placeholder_bypass_group_setting.vue';

describe('PlaceholderBypassGroupSetting', () => {
  let wrapper;

  const defaultProps = {
    minDate: new Date('2025-05-28'),
    maxDate: new Date('2026-05-28'),
    shouldDisableCheckbox: false,
    isBypassOn: false,
  };

  const futureDate = '2025-06-15';
  const ancientDate = '2019-01-01';

  const createComponent = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(PlaceholderBypassGroupSetting, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findBypassCheckbox = () => wrapper.findByTestId('placeholder-bypass-checkbox');
  const findDatepicker = () => wrapper.findComponent(GlDatepicker);
  const findHiddenCheckbox = () => wrapper.findByTestId('hidden-bypass-checkbox');
  const findHiddenDatepicker = () => wrapper.findByTestId('placeholder-bypass-hidden-expiry-date');

  it('checkbox reflects the disabled state', () => {
    createComponent({ shouldDisableCheckbox: true }, mountExtended);
    expect(findBypassCheckbox().attributes('disabled')).toBe('disabled');
  });

  it('checkbox changes will reflect in the hidden input for form submission', async () => {
    createComponent({ shouldDisableCheckbox: false }, mountExtended);
    await findBypassCheckbox().setChecked(true);
    await nextTick();

    expect(findHiddenCheckbox().attributes('value')).toBe('1');
  });

  describe('expiry date', () => {
    const setBypassCheckbox = async (shouldBe = true) => {
      const checkbox = findBypassCheckbox();
      await checkbox.setChecked(shouldBe);
    };

    it('picker passes the correct minDate', () => {
      createComponent();

      expect(findDatepicker().props('minDate')).toBe(defaultProps.minDate);
    });

    it('picker passes the correct maxDate', () => {
      createComponent();

      expect(findDatepicker().props('maxDate')).toBe(defaultProps.maxDate);
    });

    it('picker uses the currentExpiryDate when passed in', () => {
      createComponent({ currentExpiryDate: futureDate });

      expect(findDatepicker().props('value')).toEqual(new Date(futureDate));
    });

    it('picker is hidden when checkbox is disabled', () => {
      createComponent({ shouldDisableCheckbox: true });
      expect(findDatepicker().exists()).toBe(false);
    });

    it('is set by default to the min date when the checkbox is checked', async () => {
      createComponent({ shouldDisableCheckbox: false }, mountExtended);
      setBypassCheckbox();
      await nextTick();

      expect(findDatepicker().props('value')).toBe(defaultProps.minDate);
    });

    it('hidden input reflects the selectedDate value', async () => {
      createComponent({ shouldDisableCheckbox: false }, mountExtended);
      const hiddenInput = findHiddenDatepicker();

      expect(hiddenInput.element.value).toBe('');

      setBypassCheckbox(true);
      await nextTick();

      expect(hiddenInput.element.value).toBe(defaultProps.minDate.toString());
    });

    it('lets the user choose an expiry date that overrides the default date', async () => {
      createComponent({ shouldDisableCheckbox: false }, mountExtended);
      setBypassCheckbox();
      await nextTick();

      const datepicker = findDatepicker();
      expect(datepicker.props('value')).toBe(defaultProps.minDate);
      const expDate = new Date('2025-08-28');
      datepicker.vm.$emit('input', expDate);
      await nextTick();
      expect(datepicker.props('value')).toEqual(expDate);
    });

    it('is cleared when the checkbox is unchecked', async () => {
      createComponent(
        { shouldDisableCheckbox: false, isBypassOn: true, currentExpiryDate: futureDate },
        mountExtended,
      );
      setBypassCheckbox(false);
      await nextTick();

      expect(findDatepicker().vm.textInput).toBe('');
      expect(findHiddenDatepicker().element.value).toBe('');
    });

    it('picker is disabled after checkbox is unchecked', async () => {
      createComponent(
        { shouldDisableCheckbox: false, isBypassOn: true, currentExpiryDate: futureDate },
        mountExtended,
      );
      setBypassCheckbox(false);
      await nextTick();
      expect(findDatepicker().props('disabled')).toEqual(true);
    });

    it('picker is enabled after checkbox is checked', async () => {
      createComponent({ shouldDisableCheckbox: false }, mountExtended);
      setBypassCheckbox();
      await nextTick();
      expect(findDatepicker().props('disabled')).toEqual(false);
    });

    describe('when date has passed:', () => {
      it('and bypass was on, the checkbox is turned off', () => {
        createComponent({ currentExpiryDate: ancientDate, isBypassOn: true }, mountExtended);

        expect(findBypassCheckbox().element.checked).toBe(false);
      });

      it('and bypass was on, no expiry date is rendered', () => {
        createComponent({ currentExpiryDate: ancientDate, isBypassOn: true });
        expect(findDatepicker().props('value')).toEqual(null);
      });

      it('and bypass was off, the checkbox is off', () => {
        createComponent({ currentExpiryDate: ancientDate, isBypassOn: false }, mountExtended);

        expect(findBypassCheckbox().element.checked).toBe(false);
      });

      it('and bypass was off, no expiry date is rendered', () => {
        createComponent({ currentExpiryDate: ancientDate, isBypassOn: false }, mountExtended);
        expect(findDatepicker().props('value')).toEqual(null);
      });
    });
  });
});
