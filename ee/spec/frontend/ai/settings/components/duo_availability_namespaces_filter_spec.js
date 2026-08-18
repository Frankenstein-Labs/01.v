import { nextTick } from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoAvailabilityNamespacesFilter from 'ee/ai/settings/components/duo_availability_namespaces_filter.vue';
import { AVAILABILITY_OPTIONS_ENUMS } from 'ee/ai/settings/constants';

describe('DuoAvailabilityNamespacesFilter', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(DuoAvailabilityNamespacesFilter, {});
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const emitSubmit = (terms) => findFilteredSearch().vm.$emit('submit', terms);

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('defaults the value to the admin-locked=true token', () => {
      expect(findFilteredSearch().props('value')).toEqual([
        { type: 'adminLocked', value: { data: 'true', operator: '=' } },
      ]);
    });

    it('renders the expected placeholder', () => {
      expect(findFilteredSearch().props('placeholder')).toBe('Search or filter groups');
    });

    it('renders terms as tokens', () => {
      expect(findFilteredSearch().props('termsAsTokens')).toBe(true);
    });

    it('provides the adminLocked and duoAvailability tokens', () => {
      const tokens = findFilteredSearch().props('availableTokens');

      expect(tokens.map((token) => token.type)).toEqual(['adminLocked', 'duoAvailability']);
    });

    it('provides yes/no options for the adminLocked token', () => {
      const [adminLockedToken] = findFilteredSearch().props('availableTokens');

      expect(adminLockedToken.options).toEqual([
        { value: 'true', title: 'Yes' },
        { value: 'false', title: 'No' },
      ]);
    });

    it('provides the availability options for the duoAvailability token', () => {
      const [, duoAvailabilityToken] = findFilteredSearch().props('availableTokens');

      expect(duoAvailabilityToken.options.map((option) => option.value)).toEqual([
        AVAILABILITY_OPTIONS_ENUMS.ALWAYS_ON,
        AVAILABILITY_OPTIONS_ENUMS.DEFAULT_ON,
        AVAILABILITY_OPTIONS_ENUMS.DEFAULT_OFF,
        AVAILABILITY_OPTIONS_ENUMS.NEVER_ON,
      ]);
    });
  });

  describe('onInput', () => {
    it('updates the value bound to GlFilteredSearch', async () => {
      const newValue = [{ type: 'adminLocked', value: { data: 'false', operator: '=' } }];

      findFilteredSearch().vm.$emit('input', newValue);
      await nextTick();

      expect(findFilteredSearch().props('value')).toEqual(newValue);
    });
  });

  describe('handleSubmit', () => {
    it('emits filter with a free-text search term', () => {
      emitSubmit(['my search']);

      expect(wrapper.emitted('filter')[0]).toEqual([{ search: 'my search' }]);
    });

    it('trims and joins multiple free-text terms', () => {
      emitSubmit([' foo ', 'bar ']);

      expect(wrapper.emitted('filter')[0]).toEqual([{ search: 'foo bar' }]);
    });

    it('ignores blank free-text terms', () => {
      emitSubmit(['   ']);

      expect(wrapper.emitted('filter')[0]).toEqual([{}]);
    });

    it('emits adminLocked=true when the adminLocked token value is "true"', () => {
      emitSubmit([{ type: 'adminLocked', value: { data: 'true' } }]);

      expect(wrapper.emitted('filter')[0]).toEqual([{ adminLocked: true }]);
    });

    it('emits adminLocked=false when the adminLocked token value is "false"', () => {
      emitSubmit([{ type: 'adminLocked', value: { data: 'false' } }]);

      expect(wrapper.emitted('filter')[0]).toEqual([{ adminLocked: false }]);
    });

    it('uses the last adminLocked token when multiple are present', () => {
      emitSubmit([
        { type: 'adminLocked', value: { data: 'true' } },
        { type: 'adminLocked', value: { data: 'false' } },
      ]);

      expect(wrapper.emitted('filter')[0]).toEqual([{ adminLocked: false }]);
    });

    it('emits duoAvailability as an array of the selected values', () => {
      emitSubmit([
        { type: 'duoAvailability', value: { data: AVAILABILITY_OPTIONS_ENUMS.ALWAYS_ON } },
        { type: 'duoAvailability', value: { data: AVAILABILITY_OPTIONS_ENUMS.NEVER_ON } },
      ]);

      expect(wrapper.emitted('filter')[0]).toEqual([
        {
          duoAvailability: [
            AVAILABILITY_OPTIONS_ENUMS.ALWAYS_ON,
            AVAILABILITY_OPTIONS_ENUMS.NEVER_ON,
          ],
        },
      ]);
    });

    it('ignores duoAvailability tokens with no value', () => {
      emitSubmit([{ type: 'duoAvailability', value: {} }]);

      expect(wrapper.emitted('filter')[0]).toEqual([{}]);
    });

    it('combines search, adminLocked, and duoAvailability filters', () => {
      emitSubmit([
        'foo',
        { type: 'adminLocked', value: { data: 'true' } },
        { type: 'duoAvailability', value: { data: AVAILABILITY_OPTIONS_ENUMS.DEFAULT_ON } },
      ]);

      expect(wrapper.emitted('filter')[0]).toEqual([
        {
          search: 'foo',
          adminLocked: true,
          duoAvailability: [AVAILABILITY_OPTIONS_ENUMS.DEFAULT_ON],
        },
      ]);
    });

    it('emits an empty object when there is nothing to filter by', () => {
      emitSubmit([]);

      expect(wrapper.emitted('filter')[0]).toEqual([{}]);
    });
  });

  describe('onClear', () => {
    it('resets the value bound to GlFilteredSearch', async () => {
      findFilteredSearch().vm.$emit('clear');
      await nextTick();

      expect(findFilteredSearch().props('value')).toEqual([]);
    });

    it('emits filter with an empty object', () => {
      findFilteredSearch().vm.$emit('clear');

      expect(wrapper.emitted('filter')[0]).toEqual([{}]);
    });
  });
});
